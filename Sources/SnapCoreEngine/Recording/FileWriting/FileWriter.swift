//
//  FileWriter.swift
//  SnapCore
//
//  Created by Aryan Rogye on 3/26/26.
//

#if os(macOS)
import Foundation
import SnapCore

protocol FileWriter {
    
    func getOutput() async -> URL?
    
    func start(
        outputURL: URL
    ) async
    
    func write(
        sample: SendableSampleBuffer,
        info: ValidationInfo,
        onFrameWritten: @escaping () -> Void
    ) async throws
    
    func stop() async throws
}

#endif
