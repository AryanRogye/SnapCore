//
//  RecognitionHandler.swift
//  ComfyRep
//
//  Created by Aryan Rogye on 12/28/25.
//

import AVFoundation
import Vision

protocol RecognitionHandler {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection)
}

extension RecognitionHandler {
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

    /// Determines whether two arrays of body poses are "close by"
    /// by comparing the average displacement of shared joints.
    internal func isCloseBy(
        old: [BodyPose],
        new: [BodyPose],
        threshold: CGFloat = 0.08
    ) -> Bool {

        if old.count != new.count { return false }

        var usedIndices = Set<Int>()

        for oldPose in old {
            var minAvgDistance: CGFloat = .infinity
            var closestIndex: Int?

            for (idx, newPose) in new.enumerated() {
                guard !usedIndices.contains(idx) else { continue }

                let avgDist = averageJointDistance(oldPose, newPose)
                if avgDist < minAvgDistance {
                    minAvgDistance = avgDist
                    closestIndex = idx
                }
            }

            guard let idx = closestIndex, minAvgDistance < threshold else {
                return false
            }

            usedIndices.insert(idx)
        }

        return true
    }

    // MARK: - Private helpers

    /// Returns the average Euclidean distance between the joints that
    /// both poses share.  If they share no joints, returns `.infinity`.
    private func averageJointDistance(_ a: BodyPose, _ b: BodyPose) -> CGFloat {
        var totalDistance: CGFloat = 0
        var count: CGFloat = 0

        for joint in BodyJoint.allCases {
            guard let pA = a[joint],
                  let pB = b[joint],
                  pA.confidence > 0,
                  pB.confidence > 0 else {
                continue
            }

            let dx = pA.location.x - pB.location.x
            let dy = pA.location.y - pB.location.y
            totalDistance += sqrt(dx * dx + dy * dy)
            count += 1
        }

        return count > 0 ? totalDistance / count : .infinity
    }
}
