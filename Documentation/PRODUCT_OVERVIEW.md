# Kikobar Product Overview

> **Status: Active Beta**  
> Kikobar is currently under active development. Core drag ingestion, trigger mechanics, and persistent storage are functional, while broader workflow features and distribution polish are underway.

---

## What is Kikobar?

Kikobar is a native macOS drag-and-drop collection utility designed to eliminate window-juggling and ad-hoc desktop clutter. It serves as a temporary and persistent holding ground for content you encounter during daily Mac workflows—whether conducting research, gathering design assets, organizing code snippets, or staging files for transfer.

Unlike conventional clipboard managers or static staging apps, Kikobar operates as an on-demand floating drawer. It remains invisible until you drag an item toward the top-right corner of your screen, presenting categorized drop targets with minimal interruption to your active task.

---

## Core Interaction Model

The interaction follows a five-step lifecycle:

```
1. Drag Content
   (Select files in Finder, an image in Safari, a URL from Chrome, or text in an editor)
       │
       ▼
2. Approach Corner
   (Move the dragged item toward the top-right corner of any connected display)
       │
       ▼
3. Drawer Revealed
   (Trigger zone detects proximity and smoothly slides out the collection panel)
       │
       ▼
4. Drop into Category
   (Release the payload into a color-coded, labeled category target)
       │
       ▼
5. Retrieve & Manage
   (Access saved items instantly, view thumbnails, or drag them back out when ready)
```

---

## Target Audience & Use Cases

- **Designers & Creative Directors**: Collect mood-board images from browsers, reference screenshots, and SVG vectors directly from web pages without polluting the Downloads folder.
- **Developers & Engineers**: Stash stack traces, code snippets, documentation URLs, and patch files while context-switching between terminals and editors.
- **Researchers & Writers**: Clip quotes, citations, PDF references, and links during deep-dive research sessions.
- **Everyday macOS Users**: Replace messy desktop holding piles with clean, persistent, color-coded drawers.

---

## Design Principles

1. **Native Performance**: Built entirely with Swift, AppKit, and SwiftUI without web views, Electron runtimes, or cross-platform wrappers.
2. **Zero Invasive Permissions**: Employs non-activating AppKit window drag protocols rather than invasive system accessibility or screen recording hooks.
3. **Local-First & Private**: All data and files remain on the local machine in SQLite and the application container. No cloud syncing, telemetry, or third-party tracking.
4. **Minimal Aesthetic**: Crafted with dark charcoal surfaces (`#161618`), subtle borders, and lavender accents (`#8B7CFF`), fitting naturally into modern macOS Sonoma and Sequoia environments.
