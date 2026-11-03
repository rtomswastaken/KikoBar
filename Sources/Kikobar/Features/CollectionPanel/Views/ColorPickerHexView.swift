import SwiftUI

/// Color picker component with preset swatches and direct HEX code input (#RRGGBB / #RGB).
public struct ColorPickerHexView: View {
    @Binding var selectedHex: String
    var onColorChanged: ((String) -> Void)?

    @State private var hexInputText: String = ""
    @State private var isHexValid: Bool = true
    @State private var hoveredHex: String? = nil

    private let presetHexes = [
        "#8B7CFF", // Indigo/Purple
        "#FF5E7E", // Coral/Red
        "#FFAA00", // Amber/Orange
        "#38EF7D", // Emerald/Green
        "#11D3BC", // Teal/Cyan
        "#00B4D8", // Sky/Blue
        "#E056FD", // Magenta/Pink
        "#95A5A6"  // Cool Grey
    ]

    public init(selectedHex: Binding<String>, onColorChanged: ((String) -> Void)? = nil) {
        self._selectedHex = selectedHex
        self.onColorChanged = onColorChanged
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Preset Swatches
            HStack(spacing: 8) {
                ForEach(presetHexes, id: \.self) { hex in
                    let isSelected = selectedHex.uppercased() == hex.uppercased()
                    let isHovered = hoveredHex == hex

                    Circle()
                        .fill(HexColor.toColor(hex: hex))
                        .frame(width: 20, height: 20)
                        .scaleEffect(isSelected ? 1.15 : (isHovered ? 1.08 : 1.0))
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: isSelected ? 2 : 0)
                        )
                        .shadow(color: HexColor.toColor(hex: hex).opacity(isSelected ? 0.5 : (isHovered ? 0.3 : 0.15)), radius: isSelected ? 4 : 2)
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
                        .animation(.easeInOut(duration: 0.15), value: isHovered)
                        .onHover { hovering in
                            hoveredHex = hovering ? hex : nil
                        }
                        .onTapGesture {
                            selectHex(hex)
                        }
                }
            }

            // Direct HEX Input Bar
            HStack(spacing: 8) {
                // Live Color Preview Swatch
                RoundedRectangle(cornerRadius: 6)
                    .fill(HexColor.toColor(hex: selectedHex))
                    .frame(width: 26, height: 26)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: HexColor.toColor(hex: selectedHex).opacity(0.3), radius: 3)

                // Input Field
                TextField("#RRGGBB", text: $hexInputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isHexValid ? Color.secondary.opacity(0.2) : Color.red, lineWidth: isHexValid ? 1 : 1.5)
                    )
                    .onSubmit {
                        commitHexInput()
                    }
                    .onChange(of: hexInputText) { _, newValue in
                        validateAndApply(input: newValue)
                    }

                if !isHexValid {
                    Text("Invalid HEX")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.red)
                        .transition(.opacity)
                }
            }
        }
        .onAppear {
            hexInputText = selectedHex
            isHexValid = HexColor.isValid(hex: selectedHex)
        }
        .onChange(of: selectedHex) { _, newHex in
            if HexColor.sanitize(hex: hexInputText) != HexColor.sanitize(hex: newHex) {
                hexInputText = newHex
                isHexValid = HexColor.isValid(hex: newHex)
            }
        }
    }

    private func selectHex(_ hex: String) {
        selectedHex = hex
        hexInputText = hex
        isHexValid = true
        onColorChanged?(hex)
    }

    private func validateAndApply(input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let formatted = trimmed.starts(with: "#") ? trimmed : "#\(trimmed)"

        if HexColor.isValid(hex: formatted) {
            let sanitized = HexColor.sanitize(hex: formatted)
            selectedHex = sanitized
            isHexValid = true
            onColorChanged?(sanitized)
        } else {
            isHexValid = false
        }
    }

    private func commitHexInput() {
        if isHexValid {
            let sanitized = HexColor.sanitize(hex: hexInputText)
            hexInputText = sanitized
            selectedHex = sanitized
        }
    }
}
