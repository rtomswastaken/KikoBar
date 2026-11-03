import Foundation

/// Describes how the content's underlying asset is stored or referenced.
public enum StorageType: String, Codable, Sendable {
    /// Referenced local filesystem item (retains original location and uses security-scoped bookmarks).
    case reference

    /// Content imported and saved directly into Kikobar's managed container directory.
    case imported

    /// Web URL or remote reference.
    case link

    /// Raw inline text snippet.
    case text
}
