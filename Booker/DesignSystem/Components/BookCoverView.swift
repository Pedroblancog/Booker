import SwiftUI

/// Portada de un libro con su estilo flotante. Usa la imagen en caché si existe
/// y, si no, un placeholder generado. Para VoiceOver es un único elemento
/// con título, autor y estado.
struct BookCoverView: View {
    let book: Book

    var body: some View {
        Color.clear
            .aspectRatio(DS.Layout.coverAspectRatio, contentMode: .fit)
            .overlay { artwork }
            .coverStyle()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(book.accessibilityLabel)
            .accessibilityValue(book.accessibilityStatus)
    }

    @ViewBuilder
    private var artwork: some View {
        if let data = book.coverImageData, let image = Self.decodedCover(data, bookID: book.id) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            CoverPlaceholderView(
                title: book.title,
                author: book.authorLine,
                colorHex: book.dominantColorHex ?? DS.CoverPalette.hex(for: book.title)
            )
        }
    }

    /// La portada guardada se decodifica una vez, reducida, y se reutiliza
    /// en la cuadrícula y en el detalle.
    private static func decodedCover(_ data: Data, bookID: UUID) -> UIImage? {
        let key = "book-\(bookID)-\(data.count)"
        if let cached = DecodedImageCache.shared.image(for: key) { return cached }
        guard let image = ImageDecoding.image(from: data, maxPixelSize: 900) else { return nil }
        DecodedImageCache.shared.insert(image, for: key)
        return image
    }
}
