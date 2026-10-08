import AppKit
import Foundation

enum TranslateMode: String, CaseIterable, Identifiable, Sendable {
    case automatic
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: "Автоматически"
        case .manual: "Вручную"
        }
    }
}

enum TargetLanguage: String, CaseIterable, Identifiable, Sendable {
    case ru, en, zh, de, fr, es, ja, pt, it, ko, th, ka

    var id: String { rawValue }

    var code: String { rawValue.uppercased() }

    var englishName: String {
        switch self {
        case .ru: "Russian"
        case .en: "English"
        case .zh: "Simplified Chinese"
        case .de: "German"
        case .fr: "French"
        case .es: "Spanish"
        case .ja: "Japanese"
        case .pt: "Portuguese"
        case .it: "Italian"
        case .ko: "Korean"
        case .th: "Thai"
        case .ka: "Georgian"
        }
    }

    var promptName: String {
        "\(englishName) (\(code))"
    }

    var menuTitle: String {
        switch self {
        case .ru: "RU Русский"
        case .en: "EN English"
        case .zh: "ZH 中文"
        case .de: "DE Deutsch"
        case .fr: "FR Français"
        case .es: "ES Español"
        case .ja: "JA 日本語"
        case .pt: "PT Português"
        case .it: "IT Italiano"
        case .ko: "KO 한국어"
        case .th: "TH ไทย"
        case .ka: "KA ქართული"
        }
    }
}

enum ScriptKind: Sendable {
    case latin
    case cjk

    static func of(_ language: TargetLanguage) -> ScriptKind {
        switch language {
        case .zh, .ja, .ko: .cjk
        default: .latin
        }
    }
}

enum FontFamily: String, Sendable {
    case sans
    case serif
    case mono

    func nsFont(size: CGFloat, script: ScriptKind) -> NSFont {
        switch (self, script) {
        case (.sans, .latin):
            return .systemFont(ofSize: size, weight: .regular)
        case (.serif, .latin):
            return NSFont(name: "Georgia", size: size) ?? .systemFont(ofSize: size)
        case (.mono, _):
            return .monospacedSystemFont(ofSize: size, weight: .regular)
        case (.sans, .cjk):
            return NSFont(name: "PingFangSC-Regular", size: size) ?? .systemFont(ofSize: size)
        case (.serif, .cjk):
            return NSFont(name: "STSong", size: size)
                ?? NSFont(name: "PingFangSC-Regular", size: size)
                ?? .systemFont(ofSize: size)
        }
    }
}

struct RGBA: Sendable, Equatable {
    var r: CGFloat
    var g: CGFloat
    var b: CGFloat
    var a: CGFloat

    static let white = RGBA(r: 1, g: 1, b: 1, a: 1)
    static let black = RGBA(r: 0.08, g: 0.08, b: 0.08, a: 1)

    var luma: CGFloat { 0.2126 * r + 0.7152 * g + 0.0722 * b }

    /// ~0.46 is where black and white text have equal contrast (WCAG) on this gamma-encoded luma.
    var isLight: Bool { luma > 0.46 }

    var contrasting: RGBA { isLight ? .black : .white }

    var nsColor: NSColor {
        NSColor(srgbRed: r, green: g, blue: b, alpha: a)
    }
}

struct OverlayBlock: Identifiable, Sendable, Equatable {
    let id: Int
    var rect: CGRect
    var sourceText: String
    var translatedText: String
    var background: RGBA
    var foreground: RGBA
    var family: FontFamily
    var fontSize: CGFloat
}

enum PipelineStatus: Equatable {
    case idle
    case capturing
    case translating
    case error(String)
}

struct OCRLine: Sendable {
    var text: String
    var rect: CGRect
    var confidence: Float
    var charWidths: [CGFloat]
}

struct OCRBlock: Sendable {
    var id: Int
    var text: String
    var rect: CGRect
    var family: FontFamily
}
