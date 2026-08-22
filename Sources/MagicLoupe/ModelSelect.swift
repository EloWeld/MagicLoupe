import SwiftUI

/// Verified against GET https://openrouter.ai/api/v1/models on 2026-08-22.
enum OpenRouterCatalog {
    static let models: [OpenRouterModel] = [
        .init(slug: "google/gemini-2.5-flash", name: "Gemini 2.5 Flash"),
        .init(slug: "google/gemini-2.5-pro", name: "Gemini 2.5 Pro"),
        .init(slug: "google/gemini-3.5-flash", name: "Gemini 3.5 Flash"),
        .init(slug: "google/gemini-3.7-flash", name: "Gemini 3.7 Flash"),
        .init(slug: "anthropic/claude-haiku-4.5", name: "Claude Haiku 4.5"),
        .init(slug: "anthropic/claude-sonnet-4", name: "Claude Sonnet 4"),
        .init(slug: "anthropic/claude-sonnet-4.6", name: "Claude Sonnet 4.6"),
        .init(slug: "openai/gpt-4o-mini", name: "GPT-4o mini"),
        .init(slug: "openai/gpt-4.1-mini", name: "GPT-4.1 mini"),
        .init(slug: "openai/gpt-4o", name: "GPT-4o"),
        .init(slug: "openai/gpt-5-mini", name: "GPT-5 mini"),
        .init(slug: "deepseek/deepseek-chat", name: "DeepSeek Chat"),
        .init(slug: "deepseek/deepseek-v3.2", name: "DeepSeek V3.2"),
        .init(slug: "qwen/qwen-2.5-72b-instruct", name: "Qwen 2.5 72B"),
        .init(slug: "qwen/qwen3-max", name: "Qwen3 Max"),
        .init(slug: "meta-llama/llama-3.3-70b-instruct", name: "Llama 3.3 70B"),
        .init(slug: "mistralai/mistral-small-3.2-24b-instruct", name: "Mistral Small 3.2"),
        .init(slug: "x-ai/grok-4.5", name: "Grok 4.5"),
    ]

    static func lookup(_ slug: String) -> OpenRouterModel? {
        let trimmed = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        return models.first { $0.slug == trimmed }
    }
}

struct OpenRouterModel: Identifiable, Hashable {
    var slug: String
    var name: String
    var id: String { slug }
    var provider: ModelProvider { .from(slug: slug) }
}

enum ModelProvider: String {
    case openai, anthropic, google, deepseek, qwen, meta, mistral, xai, amazon, unknown

    static func from(slug: String) -> ModelProvider {
        switch slug.split(separator: "/").first.map(String.init) {
        case "openai": .openai
        case "anthropic": .anthropic
        case "google": .google
        case "deepseek": .deepseek
        case "qwen": .qwen
        case "meta-llama": .meta
        case "mistralai": .mistral
        case "x-ai": .xai
        case "amazon": .amazon
        default: .unknown
        }
    }

    var title: String {
        switch self {
        case .openai: "OpenAI"
        case .anthropic: "Anthropic"
        case .google: "Google"
        case .deepseek: "DeepSeek"
        case .qwen: "Qwen"
        case .meta: "Meta"
        case .mistral: "Mistral"
        case .xai: "xAI"
        case .amazon: "Amazon"
        case .unknown: "Custom"
        }
    }
}

struct ProviderLogo: View {
    let provider: ModelProvider
    var size: CGFloat = 22

    var body: some View {
        Canvas { context, canvasSize in
            let rect = CGRect(origin: .zero, size: canvasSize)
            let corner = min(canvasSize.width, canvasSize.height) * 0.28
            context.fill(
                Path(roundedRect: rect, cornerRadius: corner, style: .continuous),
                with: .color(background)
            )
            drawGlyph(in: &context, size: canvasSize)
        }
        .frame(width: size, height: size)
        .accessibilityLabel(provider.title)
    }

    private var background: Color {
        switch provider {
        case .openai: Color(red: 0.09, green: 0.09, blue: 0.10)
        case .anthropic: Color(red: 0.84, green: 0.45, blue: 0.29)
        case .google: Color(red: 0.96, green: 0.97, blue: 0.98)
        case .deepseek: Color(red: 0.22, green: 0.42, blue: 0.96)
        case .qwen: Color(red: 0.38, green: 0.33, blue: 0.92)
        case .meta: Color(red: 0.05, green: 0.56, blue: 0.91)
        case .mistral: Color(red: 0.98, green: 0.42, blue: 0.11)
        case .xai: Color(red: 0.08, green: 0.08, blue: 0.08)
        case .amazon: Color(red: 0.14, green: 0.16, blue: 0.20)
        case .unknown: Color.secondary.opacity(0.25)
        }
    }

    private func drawGlyph(in context: inout GraphicsContext, size: CGSize) {
        let inset = size.width * 0.22
        let box = CGRect(x: inset, y: inset, width: size.width - inset * 2, height: size.height - inset * 2)
        switch provider {
        case .openai:
            var star = Path()
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = box.width / 2
            for i in 0..<6 {
                let a = Double(i) * .pi / 3 - .pi / 2
                let p = CGPoint(x: c.x + r * CGFloat(cos(a)), y: c.y + r * CGFloat(sin(a)))
                if i == 0 { star.move(to: p) } else { star.addLine(to: p) }
            }
            star.closeSubpath()
            context.stroke(star, with: .color(.white), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
        case .google:
            let colors: [Color] = [
                Color(red: 0.26, green: 0.52, blue: 0.96),
                Color(red: 0.22, green: 0.67, blue: 0.35),
                Color(red: 0.98, green: 0.74, blue: 0.02),
                Color(red: 0.92, green: 0.26, blue: 0.21),
            ]
            for (i, color) in colors.enumerated() {
                var petal = Path()
                let a = Double(i) * .pi / 2 - .pi / 4
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let p = CGPoint(x: c.x + box.width * 0.28 * CGFloat(cos(a)), y: c.y + box.width * 0.28 * CGFloat(sin(a)))
                petal.addEllipse(in: CGRect(x: p.x - 2.1, y: p.y - 2.1, width: 4.2, height: 4.2))
                context.fill(petal, with: .color(color))
            }
        case .anthropic:
            var mark = Path()
            mark.move(to: CGPoint(x: box.midX, y: box.minY))
            mark.addLine(to: CGPoint(x: box.maxX, y: box.maxY))
            mark.addLine(to: CGPoint(x: box.minX, y: box.maxY))
            mark.closeSubpath()
            context.stroke(mark, with: .color(.white), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
        case .meta:
            var loop = Path()
            loop.addEllipse(in: CGRect(x: box.minX, y: box.minY + box.height * 0.18, width: box.width * 0.62, height: box.height * 0.64))
            loop.addEllipse(in: CGRect(x: box.maxX - box.width * 0.62, y: box.minY + box.height * 0.18, width: box.width * 0.62, height: box.height * 0.64))
            context.stroke(loop, with: .color(.white), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        case .xai:
            var x = Path()
            x.move(to: CGPoint(x: box.minX, y: box.minY))
            x.addLine(to: CGPoint(x: box.maxX, y: box.maxY))
            x.move(to: CGPoint(x: box.maxX, y: box.minY))
            x.addLine(to: CGPoint(x: box.minX, y: box.maxY))
            context.stroke(x, with: .color(.white), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        case .amazon:
            var smile = Path()
            smile.addArc(
                center: CGPoint(x: box.midX, y: box.midY - 1),
                radius: box.width * 0.42,
                startAngle: .degrees(20),
                endAngle: .degrees(160),
                clockwise: false
            )
            context.stroke(smile, with: .color(Color(red: 1, green: 0.6, blue: 0.13)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        default:
            var disc = Path()
            disc.addEllipse(in: box.insetBy(dx: 1.5, dy: 1.5))
            context.stroke(disc, with: .color(.white), style: StrokeStyle(lineWidth: 1.5))
        }
    }
}

struct ModelSelect: View {
    @Binding var slug: String
    @State private var open = false
    @State private var query = ""

    private var selected: OpenRouterModel? {
        OpenRouterCatalog.lookup(slug)
    }

    var body: some View {
        Button {
            open.toggle()
        } label: {
            HStack(spacing: 10) {
                ProviderLogo(provider: ModelProvider.from(slug: slug), size: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(selected?.name ?? "Свой slug")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                    Text(slug.isEmpty ? "Выбери модель" : slug)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.045))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $open, arrowEdge: .bottom) {
            ModelSelectMenu(slug: $slug, query: $query, isOpen: $open)
                .frame(width: 380, height: 440)
        }
        .onChange(of: open) { _, isOpen in
            if isOpen { query = "" }
        }
    }
}

private struct ModelSelectMenu: View {
    @Binding var slug: String
    @Binding var query: String
    @Binding var isOpen: Bool
    @FocusState private var searchFocused: Bool

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filtered: [OpenRouterModel] {
        let q = trimmedQuery.lowercased()
        if q.isEmpty { return OpenRouterCatalog.models }
        return OpenRouterCatalog.models.filter {
            $0.slug.lowercased().contains(q) || $0.name.lowercased().contains(q) || $0.provider.title.lowercased().contains(q)
        }
    }

    private var customSlug: String? {
        let value = trimmedQuery
        guard value.contains("/"), !value.contains(" ") else { return nil }
        if OpenRouterCatalog.lookup(value) != nil { return nil }
        return value
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Поиск или свой slug", text: $query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .onSubmit { submitCustomIfNeeded() }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if let customSlug {
                        Button {
                            choose(customSlug)
                        } label: {
                            HStack(spacing: 10) {
                                ProviderLogo(provider: .from(slug: customSlug), size: 22)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Использовать этот slug")
                                        .font(.system(size: 13, weight: .medium))
                                    Text(customSlug)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Text("Этого slug нет в проверенном списке. OpenRouter вернёт ошибку, если его не существует.")
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 6)
                    }

                    ForEach(filtered) { model in
                        Button {
                            choose(model.slug)
                        } label: {
                            HStack(spacing: 10) {
                                ProviderLogo(provider: model.provider, size: 22)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(model.name)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.primary)
                                    Text(model.slug)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if model.slug == slug {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background {
                                if model.slug == slug {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.primary.opacity(0.06))
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    if filtered.isEmpty, customSlug == nil {
                        Text("Ничего не нашли. Вставь slug вида author/model.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .padding(16)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .background(.ultraThinMaterial)
        .onAppear { searchFocused = true }
    }

    private func choose(_ value: String) {
        slug = value
        isOpen = false
    }

    private func submitCustomIfNeeded() {
        if let customSlug {
            choose(customSlug)
            return
        }
        if let only = filtered.first, filtered.count == 1 {
            choose(only.slug)
        }
    }
}
