import CoreGraphics
import Foundation

/// Calcula el color dominante de una portada como `#RRGGBB`.
protocol DominantColorExtracting: Sendable {
    func dominantColorHex(from imageData: Data) async -> String?
}

/// Implementación con ImageIO y CoreGraphics, sin UIKit.
///
/// Reduce la imagen a unos 48 px, agrupa los píxeles en cubetas de color
/// y elige la cubeta con más peso. Los colores saturados pesan más y los
/// casi blancos o casi negros (márgenes, texto) pesan muy poco, así que
/// gana el color que da carácter a la portada y no el fondo del escaneo.
struct CoreGraphicsColorExtractor: DominantColorExtracting {
    var sampleSize = 48

    func dominantColorHex(from imageData: Data) async -> String? {
        let sampleSize = sampleSize
        return await Task.detached(priority: .utility) {
            guard let image = ImageDecoding.thumbnail(from: imageData, maxPixelSize: sampleSize) else { return nil }
            return Self.dominantColorHex(in: image)
        }.value
    }

    static func dominantColorHex(in image: CGImage) -> String? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0, let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }

        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let didDraw = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard didDraw else { return nil }

        // 4 bits por canal: 4096 cubetas.
        struct Bucket { var weight = 0.0, red = 0.0, green = 0.0, blue = 0.0, count = 0.0 }
        var buckets = [Int: Bucket]()

        for offset in stride(from: 0, to: pixels.count, by: 4) {
            guard pixels[offset + 3] > 127 else { continue }
            let red = Double(pixels[offset]) / 255
            let green = Double(pixels[offset + 1]) / 255
            let blue = Double(pixels[offset + 2]) / 255

            let maxChannel = max(red, green, blue)
            let minChannel = min(red, green, blue)
            let saturation = maxChannel == 0 ? 0 : (maxChannel - minChannel) / maxChannel
            let isNearWhiteOrBlack = maxChannel < 0.08 || (minChannel > 0.92)
            let weight = isNearWhiteOrBlack ? 0.05 : 0.25 + saturation

            let key = (Int(pixels[offset]) >> 4) << 8 | (Int(pixels[offset + 1]) >> 4) << 4 | Int(pixels[offset + 2]) >> 4
            var bucket = buckets[key, default: Bucket()]
            bucket.weight += weight
            bucket.red += red
            bucket.green += green
            bucket.blue += blue
            bucket.count += 1
            buckets[key] = bucket
        }

        guard let best = buckets.values.max(by: { $0.weight < $1.weight }), best.count > 0 else { return nil }
        return hexString(red: best.red / best.count, green: best.green / best.count, blue: best.blue / best.count)
    }

    private static func hexString(red: Double, green: Double, blue: Double) -> String {
        func component(_ value: Double) -> Int { Int((min(max(value, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", component(red), component(green), component(blue))
    }
}

// MARK: - Asignación al libro

extension DominantColorExtracting {
    /// Calcula el color dominante del libro una sola vez. Sin portada,
    /// usa el mismo color que su placeholder generado, para que el tinte
    /// del detalle coincida con lo que se ve.
    @MainActor
    func assignDominantColorIfNeeded(to book: Book) async {
        guard book.dominantColorHex == nil else { return }
        if let data = book.coverImageData, let hex = await dominantColorHex(from: data) {
            book.dominantColorHex = hex
        } else {
            book.dominantColorHex = DS.CoverPalette.hex(for: book.title)
        }
    }
}
