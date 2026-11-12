import Foundation

/// Una portada descargada, con sus dimensiones reales en píxeles.
struct CoverImage: Sendable, Equatable {
    let data: Data
    let url: URL
    let pixelWidth: Int
    let pixelHeight: Int
}

protocol CoverImageProviding: Sendable {
    /// Descarga la mejor portada disponible para un resultado de búsqueda.
    func bestCover(for result: BookSearchResult) async -> CoverImage?
}

/// Prueba primero la portada de Google Books. Si no hay, o mide menos de
/// `minimumHeight` píxeles de alto, prueba las de Open Library y se queda
/// con la de mayor resolución. Descarga a través de la caché, así que lo
/// que ya se vio en el buscador no se vuelve a pedir.
struct CoverImageService: CoverImageProviding {
    var images: any ImageDataLoading = ImageDataCache.shared
    var minimumHeight = 400

    func bestCover(for result: BookSearchResult) async -> CoverImage? {
        var best: CoverImage?

        if let googleURL = result.googleCoverURL, let cover = await download(googleURL) {
            if cover.pixelHeight >= minimumHeight { return cover }
            best = cover
        }

        for url in result.openLibraryCoverURLs {
            guard let cover = await download(url) else { continue }
            if cover.pixelHeight > (best?.pixelHeight ?? 0) { best = cover }
            if cover.pixelHeight >= minimumHeight { break }
        }
        return best
    }

    func download(_ url: URL) async -> CoverImage? {
        guard let data = await images.imageData(for: url),
              let size = ImageDecoding.pixelSize(of: data)
        else { return nil }
        return CoverImage(data: data, url: url, pixelWidth: size.width, pixelHeight: size.height)
    }
}
