//
//  CursorShape.swift
//  PointerKit
//
//  Created by Aryan Rogye on 3/22/26.
//

import SwiftUI
import SwiftData

/// Observable so that we can check for changes
@Model
public class CursorConfig {
    public var name: String
    public var sizeWidth: CGFloat
    public var sizeHeight: CGFloat
    
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



public struct CursorShape: Shape {
    
    var config: CursorConfig
    
    @MainActor
    public static func makeCursorCGImage(
        config: CursorConfig,
    ) -> CGImage? {
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
        )
        
        let size : CGSize = CGSize(
            width: config.scale * config.size.width,
            height: config.scale * config.size.height
        )
        view.frame = CGRect(origin: .zero, size: size)
        
        let rep = view
            .bitmapImageRepForCachingDisplay(in: view.bounds)
        
        guard let rep else { return nil }
        
        view.cacheDisplay(in: view.bounds, to: rep)
        
        let image = NSImage(size: size)
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
        
        /// Top Center
        path.move(to: CGPoint(
            x: stemMiddleX,
            y: stemMinY
        ))
        
        /// Bottom Left Point
        path.addLine(to: CGPoint(
            x: stemMinX + distanceFromHorizontal,
            y: (stemMaxY - distanceFromBottom) + wingDistanceDown
        ))
        
        /// got to the center left with padding
        path.addLine(to: CGPoint(
            x: stemMiddleX - distanceFromCenter,
            y: stemMaxY - distanceFromBottom
        ))
        
        /// Go all the way down
        path.addLine(to: CGPoint(
            x: stemMiddleX - distanceFromCenter,
            y: stemMaxY
        ))
        
        /// go right
        path.addLine(
            to: CGPoint(
                x: stemMiddleX + distanceFromCenter,
                y: stemMaxY
            ))
        
        /// go back up
        path.addLine(
            to: CGPoint(
                x: stemMiddleX + distanceFromCenter,
                y: stemMaxY - distanceFromBottom
            ))

        /// To Right Point
        path.addLine(to: CGPoint(
            x: stemMaxX - distanceFromHorizontal,
            y: (stemMaxY - distanceFromBottom) + wingDistanceDown
        ))
        
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

