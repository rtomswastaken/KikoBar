import AppKit
import Foundation
import UniformTypeIdentifiers

/// Coordinates receiving asynchronous file promises from browsers and other apps.
public final class FilePromiseCoordinator: @unchecked Sendable {
    private let operationQueue: OperationQueue
    private let fileManager: FileManager

    public init(
        operationQueue: OperationQueue = .main,
        fileManager: FileManager = .default
    ) {
        self.operationQueue = operationQueue
        self.fileManager = fileManager
    }

    /// Checks if the given pasteboard contains promised file types or receivers.
    public func containsFilePromises(in pasteboard: NSPasteboard) -> Bool {
        if let types = pasteboard.types {
            let promiseTypeIdentifiers = [
                "com.apple.pasteboard.promised-file-url",
                "com.apple.pasteboard.promised-file-content-type",
                "com.apple.nsimage.promised-file-url"
            ]
            for identifier in promiseTypeIdentifiers {
                if types.contains(NSPasteboard.PasteboardType(identifier)) {
                    return true
                }
            }
            for draggedType in NSFilePromiseReceiver.readableDraggedTypes {
                if types.contains(NSPasteboard.PasteboardType(draggedType)) {
                    return true
                }
            }
        }

        let receivers = filePromiseReceivers(from: pasteboard)
        return !receivers.isEmpty
    }

    /// Extracts `NSFilePromiseReceiver` instances from the given pasteboard.
    public func filePromiseReceivers(from pasteboard: NSPasteboard) -> [NSFilePromiseReceiver] {
        return (pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil) as? [NSFilePromiseReceiver]) ?? []
    }

    /// Receives all promised files from the provided receivers into the destination directory.
    public func receivePromisedFiles(
        receivers: [NSFilePromiseReceiver],
        destinationDirectory: URL
    ) async throws -> [URL] {
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        var receivedURLs: [URL] = []

        for receiver in receivers {
            let url = try await receiveFile(receiver: receiver, destinationDirectory: destinationDirectory)
            receivedURLs.append(url)
        }

        return receivedURLs
    }

    /// Asynchronously receives a single promised file into the destination directory.
    public func receiveFile(
        receiver: NSFilePromiseReceiver,
        destinationDirectory: URL
    ) async throws -> URL {
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        return try await withCheckedThrowingContinuation { continuation in
            receiver.receivePromisedFiles(
                atDestination: destinationDirectory,
                options: [:],
                operationQueue: operationQueue
            ) { fileURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: fileURL)
                }
            }
        }
    }
}
