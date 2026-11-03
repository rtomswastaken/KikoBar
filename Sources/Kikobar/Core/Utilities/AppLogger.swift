import Foundation
import os

/// Unified logging facade for Kikobar using Apple's unified logging system.
public enum AppLogger {
    private static let subsystem = "com.kikobar.app"

    public static let general = Logger(subsystem: subsystem, category: "General")
    public static let drag = Logger(subsystem: subsystem, category: "DragEngine")
    public static let ui = Logger(subsystem: subsystem, category: "UI")
    public static let storage = Logger(subsystem: subsystem, category: "Storage")
    public static let persistence = Logger(subsystem: subsystem, category: "Persistence")
}
