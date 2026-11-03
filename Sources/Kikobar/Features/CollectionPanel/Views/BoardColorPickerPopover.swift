import SwiftUI

/// Elegant color palette popover for customizing an individual board's solid color.
public struct BoardColorPickerPopover: View {
    public let currentHex: String
    public var onSelectColor: (String) -> Void

    public static let palette: [String] = [
        "#7ED957", // Lime Green (Reference)
        "#E2A9F1", // Lilac Purple (Reference)
        "#545454", // Slate Grey (Reference)
        "#FF6B6B", // Coral Red
        "#4D96FF", // Sky Blue
        "#FFD93D", // Warm Sunflower
        "#FF9F45", // Orange Sorbet
        "#A66CFF", // Electric Lavender
        "#1DD1A1", // Mint Teal
        "#3B3B98", // Deep Indigo
        "#FD7272", // Soft Crimson
        "#2C3A47"  // Dark Obsidian
    ]

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BOARD COLOR")
                .font(KikobarFont.bold(size: 10))
                .foregroundColor(Color(white: 0.8))
                .tracking(0.8)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(26), spacing: 6), count: 4), spacing: 6) {
                ForEach(Self.palette, id: \.self) { hex in
                    Circle()
                        .fill(HexColor.toColor(hex: hex))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: currentHex.uppercased() == hex.uppercased() ? 2.5 : 0)
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                        .contentShape(Circle())
                        .onTapGesture {
                            onSelectColor(hex)
                        }
                }
            }
        }
        .padding(10)
        .background(Color(white: 0.12))
        .cornerRadius(10)
        .preferredColorScheme(.dark)
    }
}
