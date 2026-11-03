import Foundation

/// Explicit state machine tracking the full drag lifecycle of the Kikobar collection drawer.
/// Lifecycle: IDLE → DRAG_DETECTED → DRAWER_EXPANDED → DRAG_OVER_CATEGORY → ITEM_DROPPED → CONFIRMATION → COLLAPSED
public enum DrawerDragState: Equatable, Sendable {
    /// Inactive, narrow vertical strip sitting at the screen edge.
    case idle

    /// A drag has entered the edge trigger zone.
    case dragDetected(screen: String)

    /// The drawer has horizontally expanded from the edge, displaying categories.
    case drawerExpanded

    /// The dragged cursor is currently hovering over a specific category row.
    case dragOverCategory(categoryID: UUID)

    /// An item was successfully dropped onto a category.
    case itemDropped(categoryID: UUID)

    /// Displaying brief visual confirmation of ingestion before auto-collapsing.
    case confirmation(categoryID: UUID)

    /// Drawer is animating back to the narrow collapsed strip.
    case collapsed

    /// Whether the drawer should be rendered in its expanded horizontal state.
    public var isExpanded: Bool {
        switch self {
        case .idle, .collapsed:
            return false
        case .dragDetected, .drawerExpanded, .dragOverCategory, .itemDropped, .confirmation:
            return true
        }
    }

    /// The currently active target category identifier, if hovering, dropping, or confirming.
    public var activeCategoryID: UUID? {
        switch self {
        case .dragOverCategory(let id), .itemDropped(let id), .confirmation(let id):
            return id
        case .idle, .dragDetected, .drawerExpanded, .collapsed:
            return nil
        }
    }
}
