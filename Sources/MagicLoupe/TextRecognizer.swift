import Foundation
import Vision
import CoreGraphics

enum TextRecognizer {
    static func recognize(image: CGImage, viewSize: CGSize) async throws -> [OCRLine] {
        try await Task.detached(priority: .userInitiated) {
            try perform(image: image, viewSize: viewSize)
        }.value
    }

    nonisolated private static func perform(image: CGImage, viewSize: CGSize) throws -> [OCRLine] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        // A fixed language list silently drops every script outside it (Thai, CJK, …).
        request.automaticallyDetectsLanguage = true
        request.minimumTextHeight = 0.012

        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])

        let observations = request.results ?? []
        let imgW = CGFloat(image.width)
        let imgH = CGFloat(image.height)
        guard imgW > 0, imgH > 0, viewSize.width > 0, viewSize.height > 0 else { return [] }

        var lines: [OCRLine] = []
        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, observation.confidence >= 0.25 else { continue }

            let bb = observation.boundingBox
            let viewRect = CGRect(
                x: bb.minX * viewSize.width,
                y: (1 - bb.minY - bb.height) * viewSize.height,
                width: bb.width * viewSize.width,
                height: bb.height * viewSize.height
            ).integral
            guard viewRect.height >= 6, viewRect.width >= 6 else { continue }

            var widths: [CGFloat] = []
            for i in text.indices {
                let next = text.index(after: i)
                if let boxRange = try? candidate.boundingBox(for: i..<next) {
                    widths.append(boxRange.boundingBox.width * viewSize.width)
                }
            }

            lines.append(OCRLine(
                text: text,
                rect: viewRect,
                confidence: observation.confidence,
                charWidths: widths
            ))
        }
        return lines
    }
}

enum TextBlockGrouper {
    static func group(_ lines: [OCRLine]) -> [OCRBlock] {
        let sorted = lines.sorted { $0.rect.minY < $1.rect.minY }
        var clusters: [[OCRLine]] = []

        for line in sorted {
            if var last = clusters.last, let prev = last.last {
                let gap = line.rect.minY - prev.rect.maxY
                let xClose = abs(line.rect.minX - prev.rect.minX) < 16
                    || line.rect.intersects(CGRect(
                        x: prev.rect.minX,
                        y: line.rect.minY,
                        width: prev.rect.width,
                        height: 1
                    ))
                let heightOk = abs(line.rect.height - prev.rect.height) < max(prev.rect.height, 8) * 0.7
                if gap < max(prev.rect.height, 10) * 0.9, xClose, heightOk {
                    last.append(line)
                    clusters[clusters.count - 1] = last
                    continue
                }
            }
            clusters.append([line])
        }

        return clusters.enumerated().map { index, cluster in
            let union = cluster.map(\.rect).reduce(CGRect.null) { $0.union($1) }
            let padded = union.insetBy(dx: -1, dy: 0)
            let text = cluster.map(\.text).joined(separator: "\n")
            return OCRBlock(
                id: index,
                text: text,
                rect: padded,
                family: classify(cluster)
            )
        }
    }

    private static func classify(_ lines: [OCRLine]) -> FontFamily {
        let widths = lines.flatMap(\.charWidths).filter { $0 > 0.5 }
        if widths.count >= 8 {
            let mean = widths.reduce(0, +) / CGFloat(widths.count)
            let variance = widths.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / CGFloat(widths.count)
            let cv = mean > 0 ? sqrt(variance) / mean : 1
            if cv < 0.13 { return .mono }
        }
        let chars = lines.map(\.text.count).reduce(0, +)
        if lines.count >= 4 || chars >= 90 { return .serif }
        return .sans
    }
}
