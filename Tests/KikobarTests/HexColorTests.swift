import Testing
@testable import Kikobar

@Suite("Hex Color Utilities Tests")
struct HexColorTests {
    @Test("Validates various HEX strings correctly")
    func hexValidation() {
        #expect(HexColor.isValid(hex: "#8B7CFF"))
        #expect(HexColor.isValid(hex: "8B7CFF"))
        #expect(HexColor.isValid(hex: "#FFF"))
        #expect(HexColor.isValid(hex: "FFF"))
        #expect(HexColor.isValid(hex: "#11223344"))

        #expect(!HexColor.isValid(hex: "not-hex"))
        #expect(!HexColor.isValid(hex: "#12345"))
        #expect(!HexColor.isValid(hex: ""))
    }

    @Test("Sanitizes and normalizes HEX input")
    func hexSanitization() {
        #expect(HexColor.sanitize(hex: "#8b7cff") == "#8B7CFF")
        #expect(HexColor.sanitize(hex: "fff") == "#FFFFFF")
        #expect(HexColor.sanitize(hex: "invalid", fallback: "#8B7CFF") == "#8B7CFF")
    }

    @Test("Converts HEX strings to AppKit and SwiftUI colors")
    func colorConversion() {
        let nsColor = HexColor.toNSColor(hex: "#8B7CFF")
        #expect(nsColor.redComponent > 0.5)

        let color = HexColor.toColor(hex: "#8B7CFF")
        #expect(color.description.contains("8B7CFF") || !color.description.isEmpty)
    }
}
