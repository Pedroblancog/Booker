import SwiftUI

/// Portada de un libro con su estilo flotante, a la proporción real de la
/// imagen (sin recortes). Si no hay imagen, un placeholder generado.
/// Para VoiceOver es un único elemento con título, autor y estado.
///
/// La portada se decodifica fuera del hilo principal y se guarda ya lista
/// para pintar: la cuadrícula y el detalle comparten la misma imagen, así que
/// la transición entre ambos no parpadea.
struct BookCoverView: View {
    let book: Book

    /// Lado mayor al decodificar: nítido a pantalla completa en un iPhone @3x
    /// sin gastar memoria de más.
    static let maxPixelSize = 1400

    @State private var loaded: (key: String, image: UIImage)?

    var body: some View {
        let data = book.coverImageData
        let key = data.map { Self.cacheKey(bookID: book.id, data: $0) }
        let image = key.flatMap(Self.cachedImage) ?? loaded.flatMap { $0.key == key ? $0.image : nil }

        Color.clear
            .aspectRatio(aspectRatio(image: image, data: data), contentMode: .fit)
            .overlay { artwork(image: image, hasData: data != nil) }
            .coverStyle()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(book.accessibilityLabel)
            .accessibilityValue(book.accessibilityStatus)
            .task(id: key) { await decode(data, key: key) }
    }

    @ViewBuilder
    private func artwork(image: UIImage?, hasData: Bool) -> some View {
        if let image {
            CoverArtwork(image: image)
                .transition(.opacity)
        } else if hasData {
            // Mientras se decodifica, el color de la portada: sin texto que luego salte.
            (book.dominantColorHex.flatMap(HexColor.init)?.color ?? DS.Colors.surface)
        } else {
            CoverPlaceholderView(
                title: book.title,
                author: book.authorLine,
                colorHex: book.dominantColorHex ?? DS.CoverPalette.hex(for: book.title)
            )
        }
    }

    private func aspectRatio(image: UIImage?, data: Data?) -> CGFloat {
        if let image { return CoverArtwork.aspectRatio(of: image) }
        if let data { return CoverArtwork.aspectRatio(of: data) }
        return DS.Layout.coverAspectRatio
    }

    private func decode(_ data: Data?, key: String?) async {
        guard let data, let key, Self.cachedImage(key) == nil else { return }
        let size = Self.maxPixelSize
        let image = await Task.detached(priority: .userInitiated) {
            ImageDecoding.image(from: data, maxPixelSize: size)
        }.value
        guard let image, !Task.isCancelled else { return }
        DecodedImageCache.shared.insert(image, for: key)
        withAnimation(.easeOut(duration: 0.2)) { loaded = (key, image) }
    }

    // MARK: - Caché

    private static func cacheKey(bookID: UUID, data: Data) -> String {
        "book-\(bookID)-\(data.count)@\(maxPixelSize)"
    }

    private static func cachedImage(_ key: String) -> UIImage? {
        DecodedImageCache.shared.image(for: key)
    }

    /// Para medir la portada antes de pintarla (el libro que se abre necesita
    /// conocer su proporción).
    static func aspectRatio(of book: Book) -> CGFloat {
        guard let data = book.coverImageData else { return DS.Layout.coverAspectRatio }
        if let image = cachedImage(cacheKey(bookID: book.id, data: data)) {
            return CoverArtwork.aspectRatio(of: image)
        }
        return CoverArtwork.aspectRatio(of: data)
    }
}
