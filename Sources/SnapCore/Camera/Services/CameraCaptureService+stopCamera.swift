//
//  CameraCaptureService+stopCamera.swift
//  SnapCore
//
//  Created by Aryan Rogye on 4/19/26.
//

extension CameraCaptureService {
    /**
     * Function stops the camera
     */
    public func stopCamera() async {
        guard let session else { return }
        
        if movieOutput.isRecording {
            movieOutput.stopRecording()
        }
        
        session.beginConfiguration()
        
        for input in session.inputs {
            session.removeInput(input)
        }
        
        for output in session.outputs {
            session.removeOutput(output)
        }
        
        session.commitConfiguration()
        session.stopRunning()
        
        self.session = nil
    }
}
