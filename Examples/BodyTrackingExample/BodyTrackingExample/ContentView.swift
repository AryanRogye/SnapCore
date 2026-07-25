//
//  ContentView.swift
//  BodyTrackingExample
//
//  Created by Aryan Rogye on 7/25/26.
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

    let camera: CameraCaptureProviding = CameraCaptureService()
    let cameraActions: CameraActions
    let cameraCapture: CameraCapture
    var state: String = ""
    var message: String = ""
    let ciContext = CIContext()
    var texture: MTLTexture?
    var bodyPoses: [BodyPose] = []

    var cameraState: CameraState = .cameraStopped

    init() async {
        self.cameraActions = .init(cameraService: camera)
        self.cameraCapture = .init(cameraService: camera)
        await assignClosures()
    }

    private func assignClosures() async {
        await camera.setOnBodyResult { [weak self] bodyPoses, pixelBuffer, processingInterval in
            guard let self else { return }

            guard let texture = try? MetalHelpers.makeTexture(from: pixelBuffer) else {
                return
            }

            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)

            Task { @MainActor [weak self] in
                guard let self else { return }

                self.texture = texture
                self.bodyPoses = bodyPoses
                self.message = """
                Detected \(bodyPoses.count) body pose(s)
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
            try await camera.startCameraWithBodyTracking(
                with: device,
                fps: .sixty,
                cameraPosition: .front,
                colorSpace: .sRGB,
                optimize: false
            )
            self.cameraState = await camera.getCameraState()
        } catch {
            state = "Failed to start body tracking: \(error)"
        }
    }

    public func stop() async {
        await camera.stopCamera()
        self.cameraState = await camera.getCameraState()
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
    var cameraPosition: CameraPosition = .front

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

        try await cameraService.startCameraWithBodyTracking(
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

    @State private var viewport = MetalImageViewport()
    @State private var pinchStartZoom: CGFloat = 1.0
    @State private var isPinching = false

    struct Bone: Hashable {
        let from: BodyJoint
        let to: BodyJoint
    }

    static let bonePairs: [Bone] = [
        // Arms
        Bone(from: .leftShoulder, to: .leftElbow),
        Bone(from: .leftElbow, to: .leftWrist),
        Bone(from: .rightShoulder, to: .rightElbow),
        Bone(from: .rightElbow, to: .rightWrist),

        // Shoulders/torso
        Bone(from: .leftShoulder, to: .rightShoulder),
        Bone(from: .leftShoulder, to: .leftHip),
        Bone(from: .rightShoulder, to: .rightHip),
        Bone(from: .leftHip, to: .rightHip),

        // Legs
        Bone(from: .leftHip, to: .leftKnee),
        Bone(from: .leftKnee, to: .leftAnkle),
        Bone(from: .rightHip, to: .rightKnee),
        Bone(from: .rightKnee, to: .rightAnkle),

        // Neck/head
        Bone(from: .neck, to: .nose),
        Bone(from: .leftShoulder, to: .neck),
        Bone(from: .rightShoulder, to: .neck),
    ]

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

                ForEach(vm.bodyPoses, id: \.self) { pose in
                    // Bones first, so joints render on top
                    ForEach(Self.bonePairs, id: \.self) { bone in
                        BoneLine(
                            from: pose[bone.from],
                            to: pose[bone.to],
                            previewWidth: geo.size.width,
                            previewHeight: geo.size.height
                        )
                        .allowsHitTesting(false)
                    }

                    // Then joints
                    ForEach(pose.joints.sorted(by: { $0.key.rawValue < $1.key.rawValue }), id: \.key) { joint, point in
                        bodyPoint(
                            previewWidth: geo.size.width,
                            previewHeight: geo.size.height,
                            normalizedPoint: point.location,
                            confidence: point.confidence
                        )
                        .allowsHitTesting(false)
                    }
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

    func bodyPoint(
        previewWidth: CGFloat,
        previewHeight: CGFloat,
        normalizedPoint: CGPoint,
        confidence: Float
    ) -> some View {
        // Vision's origin is bottom-left, SwiftUI's is top-left, so flip y.
        // Also mirrored for front camera preview, so flip x too.
        let x = (1 - normalizedPoint.x) * previewWidth
        let y = (1 - normalizedPoint.y) * previewHeight

        return Circle()
            .fill(.green)
            .frame(width: 8, height: 8)
            .opacity(confidence > 0.1 ? 1 : 0.2)
            .position(x: x, y: y)
    }

    struct BoneLine: View {
        let from: BodyJointPoint?
        let to: BodyJointPoint?
        let previewWidth: CGFloat
        let previewHeight: CGFloat

        var body: some View {
            if let from, let to, from.confidence > 0.1, to.confidence > 0.1 {
                Path { path in
                    path.move(to: point(from))
                    path.addLine(to: point(to))
                }
                .stroke(.green, lineWidth: 3)
            }
        }

        private func point(_ p: BodyJointPoint) -> CGPoint {
            CGPoint(
                x: (1 - p.location.x) * previewWidth,
                y: (1 - p.location.y) * previewHeight
            )
        }
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
