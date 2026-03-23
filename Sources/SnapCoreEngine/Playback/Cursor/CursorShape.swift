//
//  CursorShape.swift
//  PointerKit
//
//  Created by Aryan Rogye on 3/22/26.
//

import SwiftUI

public struct CursorConfig {
    public var size: CGSize
    public var lineWidth: CGFloat
    public var innerColor: Color = .black
    public var outerColor: Color = .white
}

public struct CursorShape: Shape {
    @MainActor
    public static func makeCursorCGImage(
        config: CursorConfig,
    ) -> CGImage? {
        let view = NSHostingView(
            rootView:
                CursorShape()
                .fill(config.innerColor)
                .overlay {
                    CursorShape()
                        .stroke(config.outerColor, style: StrokeStyle(
                            lineWidth: config.lineWidth,
                            lineCap: .round,
                            lineJoin: .round
                        ))
                }
                .rotationEffect(.degrees(-20))
        )
        
        let size = config.size
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
        let distanceFromBottom = rect.height * 0.30
        let distanceFromCenter = rect.width * 0.08
        let distanceFromHorizontal = rect.width * 0.17
        let wingDistanceDown = rect.height * 0.05
        
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
                CursorShape()
                    .fill(.black)
                    .overlay {
                        CursorShape()
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

