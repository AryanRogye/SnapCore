//
//  CursorShape.swift
//  PointerKit
//
//  Created by Aryan Rogye on 3/22/26.
//

#if os(macOS)
import SwiftUI
import SwiftData

/// Observable so that we can check for changes
@Model
public class CursorConfig {
    public var name: String
    public var sizeWidth: CGFloat
    public var sizeHeight: CGFloat
    
    public var roundness: CGFloat = 6
    
    public var size: CGSize {
        get { CGSize(width: sizeWidth, height: sizeHeight) }
        set { sizeWidth = newValue.width; sizeHeight = newValue.height }
    }

    public var scale: CGFloat = 1
    public var lineWidth: CGFloat
    public var distanceFromBottomScale: CGFloat = 0.30
    public var distanceFromCenterScale: CGFloat = 0.08
    public var distanceFromHorizontal: CGFloat = 0.17
    public var wingDistanceDown: CGFloat = 0.05
    
    public var innerColorHex: String = "#000000"
    public var outerColorHex: String = "#FFFFFF"
    
    public var innerColor: Color { Color(hex: innerColorHex) }
    public var outerColor: Color { Color(hex: outerColorHex) }

    public init(
        name: String = "Untitled-\(UUID().uuidString)",
        size: CGSize,
        scale: CGFloat = 1,
        lineWidth: CGFloat,
        innerColor: String = "#000000",
        outerColor: String = "#FFFFFF"
    ) {
        self.name = name
        self.sizeWidth = size.width
        self.sizeHeight = size.height
        self.scale = scale
        self.lineWidth = lineWidth
        self.innerColorHex = innerColor
        self.outerColorHex = outerColor
    }
}



public struct CursorShape: Shape {
    
    var config: CursorConfig
    
    @MainActor
    public static func makeCursorCGImage(
        config: CursorConfig,
    ) -> CGImage? {
        let shadowPadding: CGFloat = 28
        
        let cursorSize = CGSize(
            width: config.scale * config.size.width,
            height: config.scale * config.size.height
        )
        
        let paddedSize = CGSize(
            width: cursorSize.width + shadowPadding * 2,
            height: cursorSize.height + shadowPadding * 2
        )

        let view = NSHostingView(
            rootView:
                CursorShape(config: config)
                .fill(config.innerColor)
                .overlay {
                    CursorShape(config: config)
                        .stroke(config.outerColor, style: StrokeStyle(
                            lineWidth: config.lineWidth,
                            lineCap: .round,
                            lineJoin: .round
                        ))
                }
                .rotationEffect(.degrees(-20))
                .padding(shadowPadding)
        )

        view.frame = CGRect(origin: .zero, size: paddedSize)

        let rep = view
            .bitmapImageRepForCachingDisplay(in: view.bounds)
        
        guard let rep else { return nil }
        
        view.cacheDisplay(in: view.bounds, to: rep)
        
        let image = NSImage(size: paddedSize)
        image.addRepresentation(rep)
        
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
    
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let stemMinY = rect.minY
        let stemMaxY = rect.maxY
        
        let stemMinX = rect.minX
        let stemMiddleX = rect.midX
        let stemMaxX = rect.maxX
        let distanceFromBottom = rect.height * config.distanceFromBottomScale
        let distanceFromCenter = rect.width * config.distanceFromCenterScale
        let distanceFromHorizontal = rect.width * config.distanceFromHorizontal
        let wingDistanceDown = rect.height * config.wingDistanceDown
        let r = config.roundness
        
        let topCenter = CGPoint(
            x: stemMiddleX,
            y: stemMinY
        )
        let bottomLeft = CGPoint(
            x: stemMinX + distanceFromHorizontal,
            y: (stemMaxY - distanceFromBottom) + wingDistanceDown
        )
        let centerInnerLeftTop = CGPoint(
            x: stemMiddleX - distanceFromCenter,
            y: stemMaxY - distanceFromBottom
        )
        let centerInnerLeftBottom = CGPoint(
            x: stemMiddleX - distanceFromCenter,
            y: stemMaxY
        )
        let centerInnerRightBottom = CGPoint(
            x: stemMiddleX + distanceFromCenter,
            y: stemMaxY
        )
        let centerInnerRightTop = CGPoint(
            x: stemMiddleX + distanceFromCenter,
            y: stemMaxY - distanceFromBottom
        )
        let bottomRight = CGPoint(
            x: stemMaxX - distanceFromHorizontal,
            y: (stemMaxY - distanceFromBottom) + wingDistanceDown
        )
        
        
        // Helper: lerp between two points by a fixed distance `t` from `a` toward `b`
        func approach(_ a: CGPoint, toward b: CGPoint, by t: CGFloat) -> CGPoint {
            let dx = b.x - a.x, dy = b.y - a.y
            let len = sqrt(dx*dx + dy*dy)
            guard len > 0 else { return a }
            let ratio = min(t / len, 0.5)
            return CGPoint(x: a.x + dx * ratio, y: a.y + dy * ratio)
        }
        
        // Rounded corner helper: arrive `r` before the corner, curve to `r` past it
        func addRoundedCorner(to corner: CGPoint, next: CGPoint) {
            let entry = approach(corner, toward: path.currentPoint ?? corner, by: r)
            // move back toward entry — the previous segment should have stopped short
            path.addLine(to: entry)
            let exit = approach(corner, toward: next, by: r)
            path.addQuadCurve(to: exit, control: corner)
        }
        
        let corners: [CGPoint] = [
            topCenter,
            bottomLeft,
            centerInnerLeftTop,
            centerInnerLeftBottom,
            centerInnerRightBottom,
            centerInnerRightTop,
            bottomRight
        ]

        path.move(to: approach(topCenter, toward: bottomRight, by: r))
        
        for i in 0..<corners.count {
            let corner = corners[i]
            let next   = corners[(i + 1) % corners.count]
            let entry  = approach(corner, toward: corners[(i - 1 + corners.count) % corners.count], by: r)
            let exit   = approach(corner, toward: next, by: r)
            path.addLine(to: entry)
            path.addQuadCurve(to: exit, control: corner)
        }
        
        path.closeSubpath()

        return path
    }
}

#Preview {
    ZStack {
        VStack {
            ZStack {
                CursorShape(config: CursorConfig(
                    size: CGSize(width: 16, height: 16),
                    lineWidth: 2,
                ))
                .fill(.black)
                .overlay {
                    CursorShape(config: CursorConfig(
                        size: CGSize(width: 16, height: 16),
                        lineWidth: 2,
                    ))
                    .stroke(.white, style: StrokeStyle(
                        lineWidth: 2,
                        lineCap: .round,
                        lineJoin: .round
                    ))
                }
            }
            .frame(width: 50, height: 50)
            .rotationEffect(.degrees(-20))
        }
    }
    .frame(width: 300, height: 300)
}


// MARK: - Color Extensions
private extension Color {
    var hexString: String {
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? .black
        let r = Int(nsColor.redComponent * 255)
        let g = Int(nsColor.greenComponent * 255)
        let b = Int(nsColor.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b)
    }
}
#endif
