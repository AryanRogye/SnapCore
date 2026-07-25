//
//  ContentView.swift
//  FaceTrackingExample
//
//  Created by Aryan Rogye on 7/24/26.
//

import SwiftUI
import SnapCore
import SnapCoreEngine
import AVFoundation
import CoreImage

enum CameraError: Error {
    case cantConfigure
}

@Observable
@MainActor
final class ViewModel {
    
    let camera = CameraCaptureService()
    let cameraActions: CameraActions
    let cameraCapture: CameraCapture
    var state: String = ""
    var message: String = ""
    let ciContext = CIContext()
    var texture: MTLTexture?
    var faceBoxes: [CGRect] = []
    
    var cameraState: CameraState = .cameraStopped
    
    init() async {
        self.cameraActions = .init(cameraService: camera)
        self.cameraCapture = .init(cameraService: camera)
        await assignClosures()
    }
    
    private func assignClosures() async {
        await camera.setOnFaceBoxes { [weak self] boxes, pixelBuffer, processingInterval in
            guard let self else { return }
            
            guard let texture = try? MetalHelpers.makeTexture(from: pixelBuffer) else {
                return
            }
            
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            
            Task { @MainActor [weak self] in
                guard let self else { return }
                
                self.texture = texture
                self.faceBoxes = boxes
                self.message = """
                Detected \(boxes.count) face(s)
                Frame size: \(width) × \(height)
                Current processing interval: \(processingInterval) seconds
                """
            }
        }
    }
    
    public func start() async {
        guard await camera.isAuthorized() else {
            self.state = "Camera Permission Required"
            return
        }
        
        let devices = await camera.searchSessions()
        
        guard let device = devices.first(where: { $0.position == .front }) else {
            print("No front camera found")
            return
        }
        
        do {
            try await camera.startCameraWithFaceTracking(
                with: device,
                fps: .sixty,
                cameraPosition: .front,
                colorSpace: .sRGB,
                optimize: true
            )
            self.cameraState = await camera.cameraState
        } catch {
            state = "Failed to start face tracking: \(error)"
        }
    }
    
    public func stop() async {
        await camera.stopCamera()
        self.cameraState = await camera.cameraState
    }
    
}

@Observable
@MainActor
class CameraActions {
    
    let cameraService: CameraCaptureProviding
    
    var cameraZoom: Float = 1
    
    /// no reason to track this as its a internal flag
    /// to know if we're currently focussing or not
    @ObservationIgnored
    var isFocusing = false
    
    @ObservationIgnored
    var isZooming = false
    
    init(cameraService: CameraCaptureProviding) {
        self.cameraService = cameraService
    }
    
    // MARK: - Zoom
    public func setZoom() {
        if isZooming { return }
        
        Task {
            defer { isZooming = false }
            self.isZooming = true
            
            await cameraService.setZoomFactorInstant(CGFloat(cameraZoom))
        }
    }
    public func setZoom(rate: Float) {
        if isZooming { return }
        
        Task {
            defer { isZooming = false }
            self.isZooming = true
            
            await cameraService.setZoomFactor(CGFloat(cameraZoom), rate: rate)
        }
    }
    
    // MARK: - Focus
    public func focus(at point: CGPoint, in size: CGSize) {
        if isFocusing { return }
        
        Task {
            defer { self.isFocusing = false }
            self.isFocusing = true
            await self.cameraService.focus(at: point, in: size)
        }
    }
}

@Observable
@MainActor
class CameraCapture {
    let cameraService: CameraCaptureProviding
    
    var devices: [AVCaptureDevice] {
        if cameraPosition == .front {
            return allDevices.filter { $0.position == .front }
        } else {
            return allDevices.filter { $0.position == .back }
        }
    }
    var allDevices: [AVCaptureDevice] = []
    
    var selectedDeviceID: String = ""
    var selectedDeviceMinZoom: CGFloat {
        devices.first { $0.uniqueID == selectedDeviceID }?.minAvailableVideoZoomFactor ?? 1.0
    }
    var selectedDeviceZoomStep: CGFloat {
        let minZoom = selectedDeviceMinZoom
        let maxZoom = selectedDeviceMaxZoom
        return (maxZoom - minZoom) / 60
    }
    var selectedDeviceMaxZoom: CGFloat {
        devices.first { $0.uniqueID == selectedDeviceID }?.maxAvailableVideoZoomFactor ?? 5.0
    }
    
    var cameraColorSpace: CameraColorSpace = .sRGB
    var cameraFPS: CameraFPS = .onetwenty
    var cameraPosition: CameraPosition = .back
    
    var sessionSearchTask: Task<Void, Never>?
    
    init(cameraService: CameraCaptureProviding) {
        self.cameraService = cameraService
        
        searchSessions()
        
        if selectedDeviceID.isEmpty {
            selectedDeviceID = devices.first?.uniqueID ?? ""
        }
    }
    
    
    public func startCamera() async throws {
        
        if selectedDeviceID.isEmpty { return }
        
        guard let selectedDevice = devices.first(where: { $0.uniqueID == selectedDeviceID }) else {
            throw CameraError.cantConfigure
        }
        
        try await cameraService.startCameraWithFaceTracking(
            with: selectedDevice,
            fps: cameraFPS,
            cameraPosition: cameraPosition,
            colorSpace: cameraColorSpace,
            optimize: false
        )
    }
    
    public func stopCamera() async {
        await cameraService.stopCamera()
    }
    
    public func switchCamera() async throws {
        cameraPosition.toggle()
        selectedDeviceID = devices.first?.uniqueID ?? ""
        await stopCamera()
        try await startCamera()
    }
    
    /**
     * This function loads in the devices we're allowed to show
     * this just ensures that only 1 search is active at a time and itll
     * keep cancelling the last one if we spam call it
     */
    public func searchSessions() {
        sessionSearchTask?.cancel()
        sessionSearchTask = Task {
            allDevices = await cameraService.searchSessions()
            if selectedDeviceID.isEmpty || !devices.contains(where: { $0.uniqueID == selectedDeviceID }) {
                selectedDeviceID = devices.first?.uniqueID ?? ""
            }
        }
    }
}



struct ContentView: View {
    
    @State private var vm: ViewModel?
    @State private var viewport = Viewport()
    @State private var isStartingCamera: Bool = false
    @State private var isStoppingCamera: Bool = false
    @State private var isSwitchingCamera: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                if let vm {
                    if ProcessInfo.isPreview {
                        Text("Preview Camera")
                            .frame(
                                maxWidth: .infinity,
                                maxHeight: .infinity
                            )
                            .modifier(overlayControls(
                                vm: vm,
                                cameraState: Binding(
                                    get: { vm.cameraState },
                                    set: { vm.cameraState = $0 }
                                ),
                                isStartingCamera: $isStartingCamera,
                                isStoppingCamera: $isStoppingCamera,
                                isSwitchingCamera: $isSwitchingCamera,
                                onStart: start,
                                onStop: stop,
                                onSwitchCamera: switchCamera
                            ))
                    } else {
                        CameraPreviewView(
                            vm: vm,
                            flashOpacity: .constant(0)
                        )
                        .modifier(overlayControls(
                            vm: vm,
                            cameraState: Binding(
                                get: { vm.cameraState },
                                set: { vm.cameraState = $0 }
                            ),
                            isStartingCamera: $isStartingCamera,
                            isStoppingCamera: $isStoppingCamera,
                            isSwitchingCamera: $isSwitchingCamera,
                            onStart: start,
                            onStop: stop,
                            onSwitchCamera: switchCamera
                        ))
                    }
                    
                }
            }
        }
        .task {
            vm = await .init()
            if !ProcessInfo.isPreview {
                start()
            }
        }
    }
    
    private func start() {
        guard let vm else { return }
        guard !ProcessInfo.isPreview else { return }
        if isStartingCamera { return }
        Task { @MainActor in
            isStartingCamera = true
            defer { isStartingCamera = false }
            await vm.start()
        }
    }
    
    private func stop() {
        guard let vm else { return }
        guard !ProcessInfo.isPreview else { return }
        if isStoppingCamera { return }
        Task { @MainActor in
            isStoppingCamera = true
            defer { isStoppingCamera = false }
            await vm.stop()
        }
    }
    
    private func switchCamera() {
        guard let vm else { return }
        guard !ProcessInfo.isPreview else { return }
        if isSwitchingCamera { return }
        Task { @MainActor in
            isSwitchingCamera = true
            defer { isSwitchingCamera = false }
            try? await vm.cameraCapture.switchCamera()
        }
    }
    
    private struct overlayControls: ViewModifier {
        
        @Bindable var vm: ViewModel
        @Binding var cameraState: CameraState
        @Binding var isStartingCamera: Bool
        @Binding var isStoppingCamera: Bool
        @Binding var isSwitchingCamera: Bool
        var onStart: () -> Void
        var onStop: () -> Void
        var onSwitchCamera: () -> Void
        
        let circleSize: CGFloat = 50
        
        func body(content: Content) -> some View {
            content
                .safeAreaInset(edge: .bottom) {
                    HStack {
                        Spacer()
                        Menu {
                            
                            Button {
                                onSwitchCamera()
                            } label: {
                                Image(systemName: "arrow.triangle.2.circlepath.camera")
                            }
                            .disabled(isSwitchingCamera)
                            
                            if cameraState == .cameraStarted {
                                Button("Stop") {
                                    onStop()
                                }
                                .disabled(isStoppingCamera)
                            }
                            if cameraState == .cameraStopped {
                                Button("Start") {
                                    onStart()
                                }
                                .disabled(isStartingCamera)
                            }
                        } label: {
                            Circle()
                                .fill(.clear)
                                .frame(width: circleSize, height: circleSize)
                                .glassEffect(.clear.interactive(), in: .circle)
                                .overlay {
                                    Image(systemName: "switch.2")
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(.primary)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                }
        }
    }
}

private struct CameraPreviewView: View {
    
    @Bindable var vm: ViewModel
    @Binding var flashOpacity: Double
    
    @State private var viewport = Viewport()
    @State private var pinchStartZoom: CGFloat = 1.0
    @State private var isPinching = false
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                MetalImageView(
                    viewport: $viewport,
                    texture: vm.texture
                )
                .frame(
                    width: geo.size.width,
                    height: geo.size.height
                )
                
                ForEach(vm.faceBoxes, id: \.self) { face in
                    faceRect(
                        previewWidth: geo.size.width,
                        previewHeight: geo.size.height,
                        normalizedFace: face
                    )
                    .allowsHitTesting(false)
                }
            }
            .frame(
                width: geo.size.width,
                height: geo.size.height
            )
            .contentShape(Rectangle())
            .simultaneousGesture(gesture(geo: geo))
            .clipped()
        }
        .ignoresSafeArea()
        .overlay {
            Color.white.opacity(flashOpacity)
                .ignoresSafeArea()
        }
    }
    
    func faceRect(
        previewWidth: CGFloat,
        previewHeight: CGFloat,
        normalizedFace: CGRect
    ) -> some View {
        let rect = normalizedFace
        
        let rectWidth = rect.width * previewWidth
        let rectHeight = rect.height * previewHeight
        
        // Use this if front camera preview is mirrored
        let x = (1 - rect.origin.x - rect.width) * previewWidth
        let y = (1 - rect.origin.y - rect.height) * previewHeight
        
        return Rectangle()
            .stroke(.green, lineWidth: 2)
            .frame(width: rectWidth, height: rectHeight)
            .position(
                x: x + rectWidth / 2,
                y: y + rectHeight / 2
            )
    }
    
    private func gesture(geo: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onEnded { value in
                self.vm.cameraActions.focus(at: value.location, in: geo.size)
            }
            .simultaneously(
                with: MagnificationGesture()
                    .onChanged { scale in
                        if !isPinching {
                            isPinching = true
                            pinchStartZoom = CGFloat(vm.cameraActions.cameraZoom)
                        }
                        
                        let minZoom = vm.cameraCapture.selectedDeviceMinZoom
                        let maxZoom = vm.cameraCapture.selectedDeviceMaxZoom
                        
                        let dampenedScale = 1.0 + (scale - 1.0) * 0.5
                        let targetZoom = min(max(pinchStartZoom * dampenedScale, minZoom), maxZoom)
                        
                        vm.cameraActions.cameraZoom = Float(targetZoom)
                        vm.cameraActions.setZoom()
                    }
                    .onEnded { _ in
                        isPinching = false
                    }
            )
    }
}


#Preview {
    ContentView()
}
