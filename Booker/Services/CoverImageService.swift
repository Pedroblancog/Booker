import Foundation

/// Una portada descargada, con sus dimensiones reales en píxeles.
struct CoverImage: Sendable, Equatable {
    let data: Data
    let url: URL
    let pixelWidth: Int
    let pixelHeight: Int
}

protocol CoverImageProviding: Sendable {
    /// Descarga la mejor portada disponible para un libro.
    func bestCover(title: String, authors: [String], candidates: [URL]) async -> CoverImage?
}

extension CoverImageProviding {
    func bestCover(for result: BookSearchResult) async -> CoverImage? {
        await bestCover(title: result.title, authors: result.authors, candidates: result.previewCoverURLs)
    }
}

/// Busca la portada más nítida. Primero la de Apple Books (la edición digital
/// de la editorial, a ~1000 × 1600 px); después, en orden, las candidatas del
/// resultado (Google a gran tamaño, Open Library, la miniatura). Se detiene en
/// cuanto una mide al menos `minimumHeight` píxeles de alto y, si ninguna llega,
/// se queda con la más grande. Descarga a través de la caché, así que lo que
/// ya se vio en el buscador no se vuelve a pedir.
struct CoverImageService: CoverImageProviding {
    var images: any ImageDataLoading = ImageDataCache.shared
    var lookup: (any CoverLookup)? = AppleBooksCoverLookup()
    /// Alto a partir del cual una portada se ve nítida a pantalla completa.
    var minimumHeight = 1000

    func bestCover(title: String, authors: [String], candidates: [URL]) async -> CoverImage? {
        var best: CoverImage?

        var urls: [URL] = []
        if let lookup, let url = await lookup.coverURL(title: title, author: authors.first) {
            urls.append(url)
        }
        urls += candidates

        for url in urls {
            guard !Task.isCancelled else { break }
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
