# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0-beta] - 2026-11-03

### Added
- **Core Domain & Contracts**: Defined `CollectionItem`, `CollectionCategory`, `ContentType`, `StorageType`, and `IngestionPayload`.
- **Top-Right Screen Edge Trigger**: Implemented `TriggerZoneWindow` and `TriggerZoneDestinationView` utilizing non-activating, borderless `NSPanel` windows positioned at the top-right screen quadrant with multi-display support.
- **Floating Collection Drawer**: Created `CollectionPanelWindow` and `CollectionPanelController` hosting SwiftUI views with spring animation slide-ins.
- **Drag Ingestion Engine**:
  - Finder file and directory ingestion supporting security-scoped bookmark references.
  - Browser image extraction supporting raw image data (`NSImage`) and managed container imports.
  - Web URL ingestion extracting titles and destination addresses.
  - Plain text snippet collection with automatic snippet file creation in local storage.
  - `NSFilePromiseReceiver` coordination for promised drag types.
- **Persistence & Storage Architecture**:
  - Thread-safe SQLite engine with WAL mode and foreign key cascading.
  - `SQLiteCategoryRepository` with CRUD, ordering, and expansion toggle persistence.
  - `SQLiteCollectionRepository` supporting categorization, search, item movement, and item count aggregation.
  - `LocalFileStorageService` managing app container directory storage and automatic file deletion upon category removal.
  - `SecurityScopedBookmarkManager` for persistent Finder references and missing-file resolution.
- **Theme & Customization**:
  - `ThemeManager` with Dark mode (default charcoal `#161618`) and Light mode (`#F7F7F9`).
  - HEX color validation, normalization, and SwiftUI/AppKit color conversion utilities (`#8B7CFF` lavender accent).
  - Category custom accent color configuration.
- **Test Suite**: 42 unit and integration tests across data models, persistence, UI coordination, and drag extraction.
