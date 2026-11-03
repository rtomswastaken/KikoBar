import Foundation
import UniformTypeIdentifiers

/// Represents the classification of content handled by Kikobar.
public enum ContentType: String, Codable, Sendable, CaseIterable {
    case file
    case image
    case video
    case audio
    case document
    case folder
    case url
    case text
    case other

    /// Detect content type from file URL or UTI string.
    public static func from(url: URL) -> ContentType {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return .folder
        }

        if let utType = UTType(filenameExtension: url.pathExtension) {
            return from(utType: utType)
        }

        return .file
    }

    /// Detect content type from UTType.
    public static func from(utType: UTType) -> ContentType {
        if utType.conforms(to: .image) {
            return .image
        } else if utType.conforms(to: .movie) || utType.conforms(to: .video) {
            return .video
        } else if utType.conforms(to: .audio) {
            return .audio
        } else if utType.conforms(to: .directory) || utType.conforms(to: .folder) {
            return .folder
        } else if utType.conforms(to: .pdf) || utType.conforms(to: .presentation) || utType.conforms(to: .spreadsheet) || utType.conforms(to: .text) {
            return .document
        } else if utType.conforms(to: .url) {
            return .url
        } else {
            return .file
        }
    }

    /// User-friendly SF Symbol icon name representing the content type.
    public var iconName: String {
        switch self {
        case .file:
            return "doc.fill"
        case .image:
            return "photo.fill"
        case .video:
            return "video.fill"
        case .audio:
            return "music.note"
        case .document:
            return "doc.text.fill"
        case .folder:
            return "folder.fill"
        case .url:
            return "link"
        case .text:
            return "text.alignleft"
        case .other:
            return "questionmark.circle.fill"
        }
    }
}
