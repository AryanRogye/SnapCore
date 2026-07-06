//
//  MatrixProfile.swift
//  SnapCore
//
//  Created by Aryan Rogye on 7/5/26.
//

import Accelerate

public struct Motif {
    public let indexA: Int      // where the first occurrence starts
    public let indexB: Int      // where its match starts
    public let distance: Float  // how similar they are (lower = more similar)
    public let length: Int      // window length used
}

public struct MatrixProfileResult {
    /// distance to nearest neighbor, per window
    public let profile: [Float]
    /// WHERE that neighbor starts, per window
    public let profileIndex: [Int]
}

public enum WaveformRecognizer {
    
    @concurrent
    public static func findAllMatching(
        in data: [Float],
        n: Int = 10,
        numberOfMatches k: Int = 5
    ) async -> [Motif] {
        guard n > 0, data.count >= n else { return [] }
        let profile = matrixProfile(in: data, n: n)
        return findTopMotifs(from: profile, k: k, n: n)
    }
    
    private static func findTopMotifs(from result: MatrixProfileResult, k: Int, n: Int) -> [Motif] {
        var claimed = Set<Int>()
        var motifs: [Motif] = []
        
        // sort window indices by their profile distance, ascending (best matches first)
        let sortedIndices = result.profile.indices.sorted { result.profile[$0] < result.profile[$1] }
        
        for i in sortedIndices {
            guard !claimed.contains(i) else { continue }
            let j = result.profileIndex[i]
            guard j >= 0, !claimed.contains(j) else { continue }
            
            motifs.append(Motif(indexA: i, indexB: j, distance: result.profile[i], length: n))
            
            // exclusion zone: mark everything within ~n/2 of both i and j as claimed
            // so we don't report the same motif again from a shifted-by-1 window
            let zone = n / 2
            for idx in max(0, i - zone)...min(result.profile.count - 1, i + zone) { claimed.insert(idx) }
            for idx in max(0, j - zone)...min(result.profile.count - 1, j + zone) { claimed.insert(idx) }
            
            if motifs.count >= k { break }
        }
        
        return motifs
    }

    private static func matrixProfile(in data: [Float], n: Int = 10) -> MatrixProfileResult {
        
        let windowCount = data.count - n + 1
        
        var matrixProfile = Array(
            repeating: Float.greatestFiniteMagnitude,
            count: windowCount
        )
        
        var matrixProfileIndex = Array(
            repeating: -1,
            count: windowCount
        )

        /// we get a slidingWindow
        var range: Range<Int> = 0..<n
        
        var means = Array(repeating: Float.zero, count: windowCount)
        var stds = Array(repeating: Float.zero, count: windowCount)
        
        /// we calculate the means beforehand
        for i in 0..<windowCount {
            // this window represents multiple T's
            let window = ContiguousArray(data[i..<(i + n)])
            
            // we grab the means and std's beforehand so we dont
            // recompute in the loop
            let mean = vDSP.mean(window)
            means[i] = mean
            stds[i] = vDSP.standardDeviation(window)
        }
        
        /// verify data has this range
        while range.lowerBound < windowCount {
            let Q = ContiguousArray(data[range])
            let i = range.lowerBound
            
            let q_mean = means[i]
            let q_std = stds[i]
            
            // guard against a flat/silent window - std=0 blows up the division
            guard q_std > 1e-8 else {
                range = (range.lowerBound + 1)..<(range.upperBound + 1)
                continue
            }
            
            // from our current window to the next n amount
            // the for loop looks something like this:
            // [[ -- ] -------- ]
            // T looks like this:
            // [[ -- ] [ -- ] ------ ]
            //    ^       ^
            //    Q       T
            // then:
            // [[ -- ] - [ -- ] ----- ]
            //    ^         ^
            //    Q         T
            // then
            // [[ -- ] -- [ -- ] ---- ]
            //    ^          ^
            //    Q          T
            for j in (i + 1)..<windowCount {
                let T = ContiguousArray(data[j..<(j + n)])
                
                let t_mean = means[j]
                let t_std = stds[j]
                guard t_std > 1e-8 else { continue }
                
                let dot = vDSP.dot(Q, T)
                
                let numerator = dot - Float(n) * q_mean * t_mean
                let denominator = Float(n) * q_std * t_std
                let d = (2 * Float(n) * (1 - numerator / denominator)).squareRoot()
                
                if d < matrixProfile[i] {
                    matrixProfile[i] = d
                    matrixProfileIndex[i] = j
                }
                if d < matrixProfile[j] {
                    matrixProfile[j] = d
                    matrixProfileIndex[j] = i
                }
            }
            
            
            /// do something
            range = (range.lowerBound + 1)..<(range.upperBound + 1)
        }
        
        return MatrixProfileResult(profile: matrixProfile, profileIndex: matrixProfileIndex)

    }
}
