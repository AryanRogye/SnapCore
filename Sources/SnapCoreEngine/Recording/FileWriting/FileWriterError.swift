//
//  FileWriterError.swift
//  SnapCore
//
//  Created by Aryan Rogye on 3/26/26.
//

enum FileWriterError: Error {
    case errorCreatingWriter
    case errorWritingToFile(String)
    case noOutputStream
}
