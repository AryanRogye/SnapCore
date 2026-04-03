//
//  PlaybackImageCoordinator+Frame.swift
//  SnapCore
//
//  Created by Aryan Rogye on 3/22/26.
//

import CoreImage
import CoreMedia
import AVFoundation

#if os(iOS)
extension PlaybackImageCoordinator {
    /**
     * Function Converts a CVPixelBuffer to a CGImage
     */
    internal func getCG(
        from pixelBuffer: CVPixelBuffer
    ) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        return ciContext.createCGImage(ciImage, from: ciImage.extent)
    }
    
    /**
     * Public api to get the frame at the time,
     * this can be useful to display the frame in the
     * clip [  image  ] [  image  ] [  image  ]
     */
    public func frame(
        at time: CMTime
    ) -> CGImage? {
        guard let pixelBuffer = videoOutput.copyPixelBuffer(
            forItemTime: time,
            itemTimeForDisplay: nil
        ) else {
            return nil
        }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        return ciContext.createCGImage(
            ciImage,
            from: ciImage.extent
        )
    }
    
    public func frame(
        for url: URL,
        at seconds: Double) async -> CGImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        
        do {
            let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
            return cgImage
        } catch {
            print("thumbnail generation failed:", error)
            return nil
        }
    }
}
#endif
