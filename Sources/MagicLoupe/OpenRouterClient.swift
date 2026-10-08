import Foundation

enum OpenRouterError: LocalizedError {
    case emptyKey
    case badURL
    case http(Int, String)
    case emptyResponse
    case decode

    var errorDescription: String? {
        switch self {
        case .emptyKey:
            "Нет API-ключа OpenRouter — открой настройки"
        case .badURL:
            "Некорректный URL OpenRouter"
        case .http(let code, let body):
            "OpenRouter \(code): \(body)"
        case .emptyResponse:
            "Пустой ответ модели"
        case .decode:
            "Не удалось разобрать JSON перевода"
        }
    }
}

struct OpenRouterClient: Sendable {
    var apiKey: String
    var model: String

    func translate(blocks: [(id: Int, text: String)], to language: TargetLanguage) async throws -> [Int: String] {
        let listed = blocks.map { "[\($0.id)] \($0.text)" }.joined(separator: "\n")
        let system = """
        You are a machine translator. Your only job is to translate on-screen UI and document text.
        Target language: \(language.promptName).
        Translate EVERY block into \(language.englishName). Do not copy the source if it is in another language.
        Keep short labels short. Preserve numbers, brand names and code identifiers.
        Reply with JSON only: {"blocks":[{"id":0,"text":"..."}]}
        Return the same ids. No markdown, no extra keys.
        """

        return try await complete([
            .init(role: "system", content: .text(system)),
            .init(
                role: "user",
                content: .text("Translate the following blocks into \(language.promptName):\n\(listed)")
            ),
        ])
    }

    /// For scripts Vision can't read (Georgian, …): the model reads the picture itself.
    /// Returns the whole translation under id 0, or nothing when the frame has no text.
    func translate(image jpeg: Data, to language: TargetLanguage) async throws -> [Int: String] {
        let prompt = """
        Read all text in this screenshot and translate it into \(language.promptName), keeping line breaks.
        Preserve numbers, brand names and code identifiers.
        Reply with JSON only: {"blocks":[{"id":0,"text":"..."}]}
        If there is no readable text, reply {"blocks":[{"id":0,"text":""}]}. No markdown, no extra keys.
        """
        return try await complete([
            .init(role: "user", content: .image(prompt: prompt, jpeg: jpeg)),
        ])
    }

    private func complete(_ messages: [ChatRequest.Message]) async throws -> [Int: String] {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OpenRouterError.emptyKey
        }
        guard let url = URL(string: "https://openrouter.ai/api/v1/chat/completions") else {
            throw OpenRouterError.badURL
        }
        let body = ChatRequest(model: model, temperature: 0, messages: messages)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://github.com/mtglitch/magic-loupe", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("Magic Loupe", forHTTPHeaderField: "X-Title")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status < 200 || status >= 300 {
            let snippet = String(decoding: data, as: UTF8.self)
            throw OpenRouterError.http(status, String(snippet.prefix(280)))
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let raw = decoded.choices.first?.message.content, !raw.isEmpty else {
            throw OpenRouterError.emptyResponse
        }
        return try parseBlocks(raw)
    }

    private func parseBlocks(_ raw: String) throws -> [Int: String] {
        let jsonData: Data
        if let start = raw.firstIndex(of: "{"), let end = raw.lastIndex(of: "}") {
            jsonData = Data(String(raw[start...end]).utf8)
        } else {
            jsonData = Data(raw.utf8)
        }
        let payload = try JSONDecoder().decode(TranslationPayload.self, from: jsonData)
        var map: [Int: String] = [:]
        for block in payload.blocks {
            map[block.id] = block.text
        }
        if map.isEmpty { throw OpenRouterError.decode }
        return map
    }
}

private struct ChatRequest: Encodable {
    let model: String
    let temperature: Double
    let messages: [Message]

    struct Message: Encodable {
        let role: String
        let content: Content
    }

    enum Content: Encodable {
        case text(String)
        case image(prompt: String, jpeg: Data)

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let text):
                try container.encode(text)
            case .image(let prompt, let jpeg):
                let url = "data:image/jpeg;base64,\(jpeg.base64EncodedString())"
                try container.encode([
                    Part(type: "text", text: prompt, image_url: nil),
                    Part(type: "image_url", text: nil, image_url: .init(url: url)),
                ])
            }
        }
    }

    struct Part: Encodable {
        let type: String
        let text: String?
        let image_url: ImageURL?

        struct ImageURL: Encodable {
            let url: String
        }
    }
}

private struct ChatResponse: Decodable {
    let choices: [Choice]
    struct Choice: Decodable {
        let message: Message
    }
    struct Message: Decodable {
        let content: String?
    }
}

private struct TranslationPayload: Decodable {
    let blocks: [Block]
    struct Block: Decodable {
        let id: Int
        let text: String
    }
}
