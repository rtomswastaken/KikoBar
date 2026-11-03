import AppKit
import Foundation

/// Defines the contract for parsing pasteboard items and converting them into ingestible items.
public protocol DragIngestionServiceProtocol: AnyObject, Sendable {
    /// Supported pasteboard types registered for dragging destinations.
    var supportedPasteboardTypes: [NSPasteboard.PasteboardType] { get }

    /// Evaluates if the dragging pasteboard contains any supported items.
    func canHandle(pasteboard: NSPasteboard) -> Bool

    /// Extracts payloads from the dragging pasteboard asynchronously.
    func extractPayloads(from pasteboard: NSPasteboard) async throws -> [IngestionPayload]

    /// Ingests an extracted payload directly into a target category.
    func ingest(payload: IngestionPayload, into categoryID: UUID) async throws -> CollectionItem
}
