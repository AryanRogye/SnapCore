import AVFoundation

extension CameraCaptureService {
    public func setOnHandResult(
        _ handler: @escaping ([HandPose], CVPixelBuffer, CFAbsoluteTime) -> Void
    ) async {
        self.onHandResult = handler
    }
}
