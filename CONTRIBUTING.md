# Contributing to Kikobar

Thank you for your interest in contributing to Kikobar. As a native macOS utility currently in active beta, we welcome contributions ranging from bug fixes and architectural refinements to documentation improvements.

---

## Code of Conduct

All contributors and participants are expected to adhere to the [Code of Conduct](CODE_OF_CONDUCT.md).

---

## Development Setup

### Prerequisites

- macOS 14.0 (Sonoma) or later
- Xcode 15.0+ or the Swift 5.9+ toolchain
- Swift Package Manager (included with Xcode / Command Line Tools)

### Building the Project

Clone the repository and build via the Swift command-line tool or open the package in Xcode:

```bash
git clone https://github.com/rtomswastaken/KikoBar.git
cd KikoBar
swift build
```

### Running the Test Suite

Kikobar maintains comprehensive test coverage across domain models, drag extraction, persistence, and UI controller lifecycle:

```bash
swift test
```

Ensure all tests pass cleanly before submitting any changes.

---

## Contribution Workflow

1. **Check Existing Issues**: Search [open issues](https://github.com/rtomswastaken/KikoBar/issues) or discussions to avoid duplicate work.
2. **Open an Issue for Major Changes**: For significant architectural changes or new feature proposals, open an issue first to discuss the design.
3. **Fork and Branch**: Create a focused topic branch from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```
4. **Adhere to Code Standards**:
   - Write idiomatic Swift adhering to standard Swift API Design Guidelines.
   - Maintain concurrency safety (`@MainActor`, `Sendable` conformance where required).
   - Keep AppKit and SwiftUI responsibilities decoupled via protocols and environment injection.
   - Include unit or integration tests for new functionality.
   - Avoid external third-party dependencies unless strictly justified; Kikobar prioritizes a lightweight, zero-dependency native footprint.
5. **Commit Conventions**: Use clear, imperative commit messages (e.g., `fix: resolve drag cancellation memory leak`, `feat: add hex color validation utility`).
6. **Submit a Pull Request**: Push your branch to your fork and submit a PR against `main`. Fill in the provided [Pull Request Template](.github/PULL_REQUEST_TEMPLATE.md).

---

## Reporting Issues

If you encounter unexpected behavior or crashes:
- Check existing reports in [GitHub Issues](https://github.com/rtomswastaken/KikoBar/issues).
- Provide macOS version, device architecture (Apple Silicon / Intel), reproduction steps, and console logs from `AppLogger` where applicable.
