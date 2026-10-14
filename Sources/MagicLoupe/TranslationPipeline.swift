import AppKit
import CoreGraphics
import Foundation

@MainActor
final class TranslationPipeline {
    private let model: AppModel
    private weak var loupe: LoupeController?
    private var inFlight: Task<Void, Never>?
    private var lastStableHash: UInt64?
    private var isRunning = false

    init(model: AppModel, loupe: LoupeController) {
        self.model = model
        self.loupe = loupe
    }

    func invalidateSnapshot() {
        lastStableHash = nil
        model.overlayBlocks = []
    }

    func translateNow() {
        inFlight?.cancel()
        inFlight = Task { @MainActor [weak self] in
            await self?.run(skipIfUnchanged: false)
        }
    }

    func translateIfChanged() {
        guard model.translateMode == .automatic else { return }
        guard !isRunning else { return }
        inFlight = Task { @MainActor [weak self] in
            await self?.run(skipIfUnchanged: true)
        }
    }

    private func run(skipIfUnchanged: Bool) async {
        guard let loupe, let window = loupe.panel else { return }
        let rect = loupe.contentRectInWindow
        guard rect.width >= 24, rect.height >= 16 else { return }

        isRunning = true
        defer { isRunning = false }

        do {
            try Task.checkCancellation()

            if skipIfUnchanged {
                let probe = try await ScreenGrabber.capture(contentRectInWindow: rect, window: window)
                let probeHash = ImageHasher.averageHash(probe)
                if let lastStableHash, ImageHasher.hamming(lastStableHash, probeHash) < 8 {
                    return
                }
            }

            model.status = .capturing
            let previous = model.overlayBlocks
            model.overlayBlocks = []
            loupe.flushOverlay()
            try await Task.sleep(for: LoupeChrome.captureSettle)
            try Task.checkCancellation()

            let image: CGImage
            do {
                image = try await ScreenGrabber.capture(contentRectInWindow: rect, window: window)
            } catch {
                model.overlayBlocks = previous
                throw error
            }
            try Task.checkCancellation()

            let lines = try await TextRecognizer.recognize(image: image, viewSize: rect.size)
            try Task.checkCancellation()
            var blocks = TextBlockGrouper.group(lines)

            // Vision found nothing: either no text, or a script it can't read (Georgian).
            // The model gets the picture and answers with one block over the whole frame.
            // ponytail: no per-line layout here; ask the model for boxes if it matters.
            let readByModel = blocks.isEmpty
            if readByModel {
                blocks = [OCRBlock(id: 0, text: "", rect: CGRect(origin: .zero, size: rect.size), family: .sans)]
            }

            let scaleX = CGFloat(image.width) / rect.width
            let scaleY = CGFloat(image.height) / rect.height
            let pixels = PixelBuffer(image: image)
            let script = ScriptKind.of(model.targetLanguage)

            var overlay: [OverlayBlock] = blocks.map { block in
                let px = CGRect(
                    x: block.rect.origin.x * scaleX,
                    y: block.rect.origin.y * scaleY,
                    width: block.rect.width * scaleX,
                    height: block.rect.height * scaleY
                )
                let bg = pixels.map { ColorSampler.medianBackground(in: $0, around: px) } ?? .white
                return OverlayBlock(
                    id: block.id,
                    rect: block.rect,
                    sourceText: block.text,
                    translatedText: block.text,
                    background: bg,
                    foreground: bg.contrasting,
                    family: block.family,
                    fontSize: max(block.rect.height * 0.72, 8)
                )
            }

            model.status = .translating
            let apiKey = try KeychainStore.load()
            let client = OpenRouterClient(apiKey: apiKey, model: model.modelSlug)
            let jpeg = Self.jpeg(image)
            let translated: [Int: String]
            if readByModel {
                guard let jpeg else { throw OpenRouterError.emptyResponse }
                translated = try await client.translate(image: jpeg, to: model.targetLanguage)
            } else {
                translated = try await client.translate(
                    blocks: blocks.map { block in
                        let r = block.rect
                        let box = [r.minY / rect.height, r.minX / rect.width, r.maxY / rect.height, r.maxX / rect.width]
                            .map { Int(($0 * 1000).rounded()) }
                        return (id: block.id, text: block.text, box: box)
                    },
                    image: jpeg,
                    to: model.targetLanguage
                )
            }
            try Task.checkCancellation()

            for i in overlay.indices {
                if let text = translated[overlay[i].id], !text.isEmpty {
                    overlay[i].translatedText = text
                }
                overlay[i].fontSize = FontFitter.size(
                    text: overlay[i].translatedText,
                    family: overlay[i].family,
                    script: script,
                    rect: overlay[i].rect
                )
            }
            overlay.removeAll { $0.translatedText.isEmpty }

            model.overlayBlocks = overlay
            loupe.flushOverlay()
            try await Task.sleep(for: .milliseconds(30))
            if let stable = try? await ScreenGrabber.capture(contentRectInWindow: rect, window: window) {
                lastStableHash = ImageHasher.averageHash(stable)
            }
            model.status = .idle
        } catch is CancellationError {
            return
        } catch {
            if (error as? CaptureError) == .permissionNeeded {
                model.status = .error("Нет записи экрана. Меню LangLens → Разрешения")
            } else {
                model.status = .error(error.localizedDescription)
            }
        }
    }

    /// Long side capped so a full-screen Retina frame stays under provider image limits (~5 MB).
    private static func jpeg(_ image: CGImage, maxSide: CGFloat = 2560) -> Data? {
        var source = image
        let scale = maxSide / CGFloat(max(image.width, image.height))
        if scale < 1 {
            let w = Int(CGFloat(image.width) * scale)
            let h = Int(CGFloat(image.height) * scale)
            guard let ctx = CGContext(
                data: nil,
                width: w,
                height: h,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ) else { return nil }
            ctx.interpolationQuality = .high
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            guard let scaled = ctx.makeImage() else { return nil }
            source = scaled
        }
        return NSBitmapImageRep(cgImage: source).representation(using: .jpeg, properties: [.compressionFactor: 0.85])
    }
}
