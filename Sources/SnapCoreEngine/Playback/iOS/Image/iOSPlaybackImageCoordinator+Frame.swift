//
//  PlaybackImageCoordinator+Frame.swift
//  SnapCore
//
//  Created by Aryan Rogye on 3/22/26.
//

import CoreImage
import CoreMedia

#if os(iOS)
extension PlaybackImageCoordinator {
    /// Function Converts a CVPixelBuffer to a CGImage
    internal func getCG(
        from pixelBuffer: CVPixelBuffer
    ) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        return ciContext.createCGImage(ciImage, from: ciImage.extent)
    }
}
#endif
