import SwiftUI
import Combine

struct SettingsView: View {
    @Bindable var model: AppModel
    @State private var apiKey = ""
    @State private var message: String?
    @State private var permissionTick = 0

    var body: some View {
        Form {
            Section("OpenRouter") {
                HStack(spacing: 8) {
                    SecureField("API-ключ", text: $apiKey)
                    Button("Сохранить") {
                        do {
                            try KeychainStore.save(apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
                            model.hasAPIKey = !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            model.persist()
                            message = "Сохранено"
                        } catch {
                            message = error.localizedDescription
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .fixedSize()
                }
                if let message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ModelSelect(slug: $model.modelSlug)
                    .onChange(of: model.modelSlug) { _, _ in
                        model.persist()
                    }
            }

            Section("Перевод") {
                Picker("Режим", selection: $model.translateMode) {
                    ForEach(TranslateMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .onChange(of: model.translateMode) { _, _ in
                    model.persist()
                }

                Picker("Язык по умолчанию", selection: $model.targetLanguage) {
                    ForEach(TargetLanguage.allCases) { language in
                        Text(language.menuTitle).tag(language)
                    }
                }
                .onChange(of: model.targetLanguage) { _, _ in
                    model.persist()
                }
            }

            Section("Оформление") {
                Picker("Скин", selection: $model.skin) {
                    ForEach(LoupeSkin.allCases) { skin in
                        Text(skin.title).tag(skin)
                    }
                }
                .onChange(of: model.skin) { _, _ in
                    model.persist()
                }
                Text(model.skin.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Разрешения macOS") {
                ForEach(AppPermission.allCases) { permission in
                    PermissionStatusRow(permission: permission)
                }
                .id(permissionTick)

                Text("Если macOS перезапустит приложение своим Quit & Reopen, снова откроется экран разрешений — уже с галочкой.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Открыть Access-wall") {
                    AccessWallController.shared.present()
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .frame(minWidth: 500, minHeight: 560)
        .onAppear {
            apiKey = (try? KeychainStore.load()) ?? ""
        }
        .onReceive(Timer.publish(every: 1.2, on: .main, in: .common).autoconnect()) { _ in
            permissionTick += 1
        }
    }
}

private struct PermissionStatusRow: View {
    let permission: AppPermission

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: permission.symbol)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(permission.title)
                Text(permission.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            switch permission.status {
            case .granted:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .help("Разрешено")
            case .needsRelaunch:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.orange)
                    .help("macOS ещё не применил разрешение")
            case .missing:
                Image(systemName: "circle")
                    .foregroundStyle(.secondary)
                    .help("Не выдано")
            }
        }
    }
}

