import AVFoundation

extension CameraCaptureService {
    public func setOnDetailedFaceResult(
        _ handler: @escaping ([DetailedFace], CVPixelBuffer, CFAbsoluteTime) -> Void
    ) async {
        self.onDetailedFaceResult = handler
    }
}
