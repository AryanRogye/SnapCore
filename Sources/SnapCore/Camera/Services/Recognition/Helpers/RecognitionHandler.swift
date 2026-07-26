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

    /// Determines whether two arrays of 3D body poses are "close by"
    /// by comparing the average 3D displacement of shared joints.
    internal func isCloseBy(
        old: [BodyPose3D],
        new: [BodyPose3D],
        threshold: Float = 0.05
    ) -> Bool {
        if old.count != new.count { return false }

        var usedIndices = Set<Int>()

        for oldPose in old {
            var minAvgDistance: Float = .infinity
            var closestIndex: Int?

            for (idx, newPose) in new.enumerated() {
                guard !usedIndices.contains(idx) else { continue }

                let avgDist = averageJointDistance3D(oldPose, newPose)
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

    /// Determines whether two arrays of hand poses are close by by comparing
    /// the average displacement of shared landmarks.
    internal func isCloseBy(
        old: [HandPose],
        new: [HandPose],
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

            guard let idx = closestIndex, minAvgDistance < threshold else { return false }
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

    /// Returns the average Euclidean distance in 3D space between the joints that
    /// both poses share.  If they share no joints, returns `.infinity`.
    private func averageJointDistance3D(_ a: BodyPose3D, _ b: BodyPose3D) -> Float {
        var totalDistance: Float = 0
        var count: Float = 0

        for joint in Body3DJoint.allCases {
            guard let pA = a[joint],
                  let pB = b[joint] else {
                continue
            }

            let tA = pA.translation
            let tB = pB.translation
            let dx = tA.x - tB.x
            let dy = tA.y - tB.y
            let dz = tA.z - tB.z
            totalDistance += sqrt(dx * dx + dy * dy + dz * dz)
            count += 1
        }

        return count > 0 ? totalDistance / count : .infinity
    }

    private func averageJointDistance(_ a: HandPose, _ b: HandPose) -> CGFloat {
        var totalDistance: CGFloat = 0
        var count: CGFloat = 0

        for joint in HandJoint.allCases {
            guard let pA = a[joint],
                  let pB = b[joint],
                  pA.confidence > 0,
                  pB.confidence > 0 else { continue }

            let dx = pA.location.x - pB.location.x
            let dy = pA.location.y - pB.location.y
            totalDistance += sqrt(dx * dx + dy * dy)
            count += 1
        }

        return count > 0 ? totalDistance / count : .infinity
    }
}
