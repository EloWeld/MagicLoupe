import AppKit
import CoreGraphics
import Foundation

struct PixelBuffer: Sendable {
    let width: Int
    let height: Int
    private let bytesPerRow: Int
    private let data: [UInt8]

    init?(image: CGImage) {
        let w = image.width
        let h = image.height
        let bpr = w * 4
        var pixels = [UInt8](repeating: 0, count: bpr * h)
        let drawn = pixels.withUnsafeMutableBytes { raw -> Bool in
            guard let ctx = CGContext(
                data: raw.baseAddress,
                width: w,
                height: h,
                bitsPerComponent: 8,
                bytesPerRow: bpr,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            ctx.translateBy(x: 0, y: CGFloat(h))
            ctx.scaleBy(x: 1, y: -1)
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return nil }
        width = w
        height = h
        bytesPerRow = bpr
        data = pixels
    }

    func pixel(x: Int, y: Int) -> RGBA? {
        guard x >= 0, y >= 0, x < width, y < height else { return nil }
        let o = y * bytesPerRow + x * 4
        return RGBA(
            r: CGFloat(data[o]) / 255,
            g: CGFloat(data[o + 1]) / 255,
            b: CGFloat(data[o + 2]) / 255,
            a: 1
        )
    }
}

enum ColorSampler {
    static func medianBackground(in buffer: PixelBuffer, around rect: CGRect) -> RGBA {
        let pad = 5
        let minX = max(Int(rect.minX.rounded(.down)) - pad, 0)
        let maxX = min(Int(rect.maxX.rounded(.up)) + pad, buffer.width - 1)
        let minY = max(Int(rect.minY.rounded(.down)) - pad, 0)
        let maxY = min(Int(rect.maxY.rounded(.up)) + pad, buffer.height - 1)
        guard maxX > minX, maxY > minY else { return .white }

        let inner = rect.insetBy(dx: 0.5, dy: 0.5)
        var samples: [RGBA] = []
        samples.reserveCapacity(256)
        let step = max(1, min((maxX - minX) / 24, (maxY - minY) / 24, 4))

        for y in stride(from: minY, through: maxY, by: step) {
            for x in stride(from: minX, through: maxX, by: step) {
                if inner.contains(CGPoint(x: x, y: y)) { continue }
                if let p = buffer.pixel(x: x, y: y) {
                    samples.append(p)
                }
            }
        }

        guard !samples.isEmpty else { return .white }
        samples.sort { $0.luma < $1.luma }
        return samples[samples.count / 2]
    }
}

enum FontFitter {
    static func size(text: String, family: FontFamily, script: ScriptKind, rect: CGRect) -> CGFloat {
        guard rect.width > 4, rect.height > 4, !text.isEmpty else { return 10 }
        var lo: CGFloat = 7
        var hi = min(max(rect.height * 0.95, 8), 56)
        var best = lo
        let box = CGSize(width: max(rect.width, 8), height: .greatestFiniteMagnitude)
        while hi - lo > 0.35 {
            let mid = (lo + hi) / 2
            let font = family.nsFont(size: mid, script: script)
            let bounds = (text as NSString).boundingRect(
                with: box,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font]
            )
            if bounds.height <= rect.height && bounds.width <= rect.width + 1 {
                best = mid
                lo = mid
            } else {
                hi = mid
            }
        }
        return best
    }
}
