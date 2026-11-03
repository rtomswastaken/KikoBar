import AppKit
import CoreText
import SwiftUI

/// Manages registration and access to Poppins fonts throughout Kikobar.
public enum KikobarFont {
    private static var isRegistered: Bool = false

    /// Registers the bundled Poppins fonts with CoreText.
    public static func registerFonts() {
        guard !isRegistered else { return }
        isRegistered = true

        let fontFiles = [
            "Poppins-Bold.ttf",
            "Poppins-Medium.ttf",
            "Poppins-Regular.ttf",
            "Poppins-SemiBold.ttf"
        ]

        var searchURLs: [URL] = []

        // 1. Check Bundle.main resources
        if let resourceURL = Bundle.main.resourceURL {
            let fontsDir = resourceURL.appendingPathComponent("Fonts")
            searchURLs.append(fontsDir)
            searchURLs.append(resourceURL)
        }

        // 2. Check current working directory / relative paths
        let cwd = FileManager.default.currentDirectoryPath
        searchURLs.append(URL(fileURLWithPath: "\(cwd)/Resources/Fonts"))
        searchURLs.append(URL(fileURLWithPath: "\(cwd)/build/Kikobar.app/Contents/Resources/Fonts"))

        // 3. System Library Fonts
        searchURLs.append(URL(fileURLWithPath: "/Library/Fonts"))

        for filename in fontFiles {
            for dir in searchURLs {
                let fontURL = dir.appendingPathComponent(filename)
                if FileManager.default.fileExists(atPath: fontURL.path) {
                    var error: Unmanaged<CFError>?
                    CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error)
                    break
                }
            }
        }
    }

    // MARK: - SwiftUI Fonts

    public static func bold(size: CGFloat) -> Font {
        registerFonts()
        if NSFont(name: "Poppins-Bold", size: size) != nil {
            return Font.custom("Poppins-Bold", size: size)
        }
        return .system(size: size, weight: .bold, design: .default)
    }

    public static func medium(size: CGFloat) -> Font {
        registerFonts()
        if NSFont(name: "Poppins-Medium", size: size) != nil {
            return Font.custom("Poppins-Medium", size: size)
        }
        return .system(size: size, weight: .medium, design: .default)
    }

    public static func regular(size: CGFloat) -> Font {
        registerFonts()
        if NSFont(name: "Poppins-Regular", size: size) != nil {
            return Font.custom("Poppins-Regular", size: size)
        }
        return .system(size: size, weight: .regular, design: .default)
    }

    public static func semiBold(size: CGFloat) -> Font {
        registerFonts()
        if NSFont(name: "Poppins-SemiBold", size: size) != nil {
            return Font.custom("Poppins-SemiBold", size: size)
        }
        return .system(size: size, weight: .semibold, design: .default)
    }

    public static var boardTitle: Font {
        bold(size: 13)
    }

    public static var secondary: Font {
        medium(size: 11)
    }

    public static var body: Font {
        regular(size: 12)
    }
}
