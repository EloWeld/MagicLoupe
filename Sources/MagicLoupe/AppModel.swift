import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    var isLoupeVisible = true
    var isLocked: Bool
    var translateMode: TranslateMode
    var targetLanguage: TargetLanguage
    var skin: LoupeSkin
    var modelSlug: String
    var hasAPIKey = false
    var overlayBlocks: [OverlayBlock] = []
    var status: PipelineStatus = .idle

    init() {
        let defaults = UserDefaults.standard
        modelSlug = defaults.string(forKey: Keys.modelSlug) ?? "google/gemini-2.5-flash"
        translateMode = TranslateMode(rawValue: defaults.string(forKey: Keys.translateMode) ?? "") ?? .manual
        targetLanguage = TargetLanguage(rawValue: defaults.string(forKey: Keys.targetLanguage) ?? "") ?? .ru
        skin = LoupeSkin(rawValue: defaults.string(forKey: Keys.skin) ?? "") ?? .glass
        isLocked = defaults.object(forKey: Keys.isLocked) as? Bool ?? true
        hasAPIKey = ((try? KeychainStore.load()) ?? "").isEmpty == false
    }

    func persist() {
        let defaults = UserDefaults.standard
        defaults.set(modelSlug, forKey: Keys.modelSlug)
        defaults.set(translateMode.rawValue, forKey: Keys.translateMode)
        defaults.set(targetLanguage.rawValue, forKey: Keys.targetLanguage)
        defaults.set(skin.rawValue, forKey: Keys.skin)
        defaults.set(isLocked, forKey: Keys.isLocked)
    }

    private enum Keys {
        static let modelSlug = "modelSlug"
        static let translateMode = "translateMode"
        static let targetLanguage = "targetLanguage"
        static let skin = "loupeSkin"
        static let isLocked = "isLocked"
    }
}
