import ImageIO
import UIKit

/// Lectura y reducción de imágenes con ImageIO. Reducir al tamaño en que
/// se va a pintar ahorra memoria y hace que el desplazamiento sea fluido.
enum ImageDecoding {
    /// Lee las dimensiones sin decodificar la imagen entera.
    static func pixelSize(of data: Data) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return (width, height)
    }

    /// Decodifica la imagen reducida a `maxPixelSize` por su lado mayor.
    static func thumbnail(from data: Data, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// SwiftUI no puede crear un `Image` desde `Data` en iOS 17 sin pasar por UIImage.
    static func image(from data: Data, maxPixelSize: Int) -> UIImage? {
        thumbnail(from: data, maxPixelSize: maxPixelSize).map(UIImage.init(cgImage:))
    }
}

/// Imágenes ya decodificadas, listas para pintar. Se consulta de forma
/// síncrona al crear una vista, para que lo ya visto aparezca sin parpadeo.
/// `NSCache` es seguro entre hilos y libera memoria por sí solo si hace falta.
final class DecodedImageCache: @unchecked Sendable {
    static let shared = DecodedImageCache()

    private let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 300
        return cache
    }()

    func image(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func insert(_ image: UIImage, for key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}
