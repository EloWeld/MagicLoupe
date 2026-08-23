import AppKit
import CoreText
import Foundation

enum PixelFont {
    static func register() {
        let files = ["PixelifySans.ttf", "PressStart2P-Regular.ttf"]
        var folders: [URL] = []
        if let resource = Bundle.main.resourceURL {
            folders.append(resource)
        }
        let here = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/Fonts")
        folders.append(here)

        for folder in folders {
            for file in files {
                let url = folder.appendingPathComponent(file)
                guard FileManager.default.fileExists(atPath: url.path) else { continue }
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }

    static func ui(size: CGFloat) -> NSFont {
        NSFont(name: "Pixelify Sans", size: size)
            ?? NSFont(name: "PixelifySans-Regular", size: size)
            ?? .monospacedSystemFont(ofSize: size, weight: .medium)
    }

    static func title(size: CGFloat) -> NSFont {
        NSFont(name: "Press Start 2P", size: size)
            ?? NSFont(name: "PressStart2P-Regular", size: size)
            ?? ui(size: size)
    }

    static func overlay(size: CGFloat, script: ScriptKind) -> NSFont {
        let stepped = max(10, (size / 2).rounded() * 2)
        if script == .cjk {
            return FontFamily.sans.nsFont(size: stepped, script: .cjk)
        }
        return ui(size: stepped)
    }
}
