import AppKit
import SwiftUI

/// Utility for validating, formatting, and converting Hex color strings to AppKit and SwiftUI colors.
public struct HexColor: Sendable {
    /// Validates if a given string is a valid HEX color code (e.g., "#8B7CFF", "8B7CFF", "#FFF").
    public static func isValid(hex: String) -> Bool {
        let cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        let validHexCharacters = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
        guard CharacterSet(charactersIn: cleanHex).isSubset(of: validHexCharacters) else {
            return false
        }
        return cleanHex.count == 3 || cleanHex.count == 6 || cleanHex.count == 8
    }

    /// Normalizes a hex string to canonical uppercase `#RRGGBB` format.
    public static func sanitize(hex: String, fallback: String = "#8B7CFF") -> String {
        let cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard isValid(hex: cleanHex) else { return fallback }

        if cleanHex.count == 3 {
            let r = cleanHex[cleanHex.startIndex]
            let g = cleanHex[cleanHex.index(cleanHex.startIndex, offsetBy: 1)]
            let b = cleanHex[cleanHex.index(cleanHex.startIndex, offsetBy: 2)]
            return "#\(r)\(r)\(g)\(g)\(b)\(b)".uppercased()
        } else if cleanHex.count == 6 {
            return "#\(cleanHex)".uppercased()
        } else if cleanHex.count == 8 {
            return "#\(cleanHex.prefix(6))".uppercased()
        }
        return fallback
    }

    /// Converts a hex string into an AppKit `NSColor`.
    public static func toNSColor(hex: String, fallback: NSColor = .systemPurple) -> NSColor {
        let cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var hexNumber: UInt64 = 0
        let scanner = Scanner(string: cleanHex)
        guard scanner.scanHexInt64(&hexNumber) else {
            return fallback
        }

        let r, g, b, a: CGFloat
        switch cleanHex.count {
        case 3:
            r = CGFloat((hexNumber & 0xF00) >> 8) / 15.0
            g = CGFloat((hexNumber & 0x0F0) >> 4) / 15.0
            b = CGFloat(hexNumber & 0x00F) / 15.0
            a = 1.0
        case 6:
            r = CGFloat((hexNumber & 0xFF0000) >> 16) / 255.0
            g = CGFloat((hexNumber & 0x00FF00) >> 8) / 255.0
            b = CGFloat(hexNumber & 0x0000FF) / 255.0
            a = 1.0
        case 8:
            r = CGFloat((hexNumber & 0xFF000000) >> 24) / 255.0
            g = CGFloat((hexNumber & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((hexNumber & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(hexNumber & 0x000000FF) / 255.0
        default:
            return fallback
        }

        return NSColor(calibratedRed: r, green: g, blue: b, alpha: a)
    }

    /// Converts a hex string into a SwiftUI `Color`.
    public static func toColor(hex: String, fallback: Color = Color.purple) -> Color {
        let nsColor = toNSColor(hex: hex)
        return Color(nsColor: nsColor)
    }
}
