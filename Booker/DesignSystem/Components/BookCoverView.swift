import SwiftUI
import UIKit

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
        // SwiftUI no tiene en iOS 17 una forma de crear `Image` a partir de `Data`
        // sin pasar por UIImage.
        if let data = book.coverImageData, let image = UIImage(data: data) {
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
}
