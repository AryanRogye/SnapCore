//
//  FaceRecognitionHandler.swift
//  ComfyRep
//
//  Created by Aryan Rogye on 12/28/25.
//

import AVFoundation
import Vision

protocol FaceRecognitionHandler {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection)
}

extension FaceRecognitionHandler {
    internal func isCloseBy(
        old: [CGRect],
        new: [CGRect],
        threshold: CGFloat = 0.08
    ) -> Bool {
        
        if old.count != new.count {
            return false
        }
        
        var usedIndices = Set<Int>()
        
        for oldRect in old {
            let oldCenter = CGPoint(x: oldRect.midX, y: oldRect.midY)
            
            var minDistance: CGFloat = .infinity
            var closestIndex: Int?
            
            for (idx, newRect) in new.enumerated() {
                guard !usedIndices.contains(idx) else { continue }
                
                let newCenter = CGPoint(x: newRect.midX, y: newRect.midY)
                let dx = newCenter.x - oldCenter.x
                let dy = newCenter.y - oldCenter.y
                let distance = sqrt(dx * dx + dy * dy)
                
                if distance < minDistance {
                    minDistance = distance
                    closestIndex = idx
                }
            }
            
            guard let idx = closestIndex, minDistance < threshold else {
                return false
            }
            
            usedIndices.insert(idx)
        }
        
        return true
    }
}
