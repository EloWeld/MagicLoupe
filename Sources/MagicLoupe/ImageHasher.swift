import CoreGraphics

enum ImageHasher {
    static func averageHash(_ image: CGImage) -> UInt64 {
        let size = 8
        guard let ctx = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return 0 }

        ctx.interpolationQuality = .low
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
        guard let data = ctx.data else { return 0 }
        let ptr = data.bindMemory(to: UInt8.self, capacity: size * size)

        var total = 0
        for i in 0..<(size * size) { total += Int(ptr[i]) }
        let avg = total / (size * size)

        var hash: UInt64 = 0
        for i in 0..<(size * size) {
            if Int(ptr[i]) >= avg {
                hash |= 1 << i
            }
        }
        return hash
    }

    static func hamming(_ a: UInt64, _ b: UInt64) -> Int {
        (a ^ b).nonzeroBitCount
    }
}
