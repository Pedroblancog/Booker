import SwiftUI

/// El libro del detalle: la portada gira sobre el lomo y descubre el pliego
/// interior, con la guarda a la izquierda y la primera página a la derecha.
///
/// Cerrado ocupa el ancho de una portada; abierto, el de dos páginas, así que
/// el conjunto se desplaza para quedar siempre centrado.
struct OpeningBookView<Page: View>: View {
    let book: Book
    let isOpen: Bool
    /// Ancho de una página (y de la portada).
    let pageWidth: CGFloat
    @ViewBuilder let page: Page

    /// Casi plano: un poco de inclinación deja ver que es una tapa.
    private static var openAngle: Double { -168 }

    var body: some View {
        let pageHeight = pageWidth / DS.Layout.coverAspectRatio

        ZStack(alignment: .leading) {
            page
                .frame(width: pageWidth, height: pageHeight, alignment: .topLeading)
                .background(PagePaper(colorHex: book.dominantColorHex))
                .clipShape(UnevenRoundedRectangle(bottomTrailingRadius: DS.Radius.cover, topTrailingRadius: DS.Radius.cover))
                .shadow(color: .black.opacity(0.12), radius: 14, y: 10)
                .accessibilityElement(children: .contain)
                .accessibilityHidden(!isOpen)

            HingedCover(angle: isOpen ? Self.openAngle : 0) {
                BookCoverView(book: book)
                    .frame(width: pageWidth)
            } back: {
                Endpaper(colorHex: book.dominantColorHex)
                    .frame(width: pageWidth, height: pageHeight)
            }
            .accessibilityHidden(isOpen)
        }
        .frame(width: pageWidth, height: pageHeight)
        // Abierto, el pliego mide dos páginas: se centra desplazando la mitad.
        .offset(x: isOpen ? pageWidth / 2 : 0)
    }
}

// MARK: - Tapa con bisagra

/// Gira sobre su borde izquierdo y, al pasar de 90°, muestra la cara
/// interior en vez de la portada (como una tapa de verdad).
private struct HingedCover<Front: View, Back: View>: View, Animatable {
    var angle: Double
    @ViewBuilder let front: Front
    @ViewBuilder let back: Back

    nonisolated var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        let showsBack = angle < -90
        ZStack {
            front.opacity(showsBack ? 0 : 1)
            // Se refleja para que, vista del revés, la guarda no salga en espejo.
            back
                .scaleEffect(x: -1, y: 1)
                .opacity(showsBack ? 1 : 0)
        }
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.4)
    }
}

// MARK: - Papel

/// Papel de la primera página, con un velo muy suave del color de la portada.
private struct PagePaper: View {
    let colorHex: String?

    var body: some View {
        ZStack {
            DS.Colors.surface
            TintGradient(colorHex: colorHex).opacity(0.6)
            // Sombra del pliegue junto al lomo.
            LinearGradient(colors: [.black.opacity(0.10), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 18)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Guarda: el interior de la tapa, del color de la portada oscurecido,
/// con un pequeño ex libris.
private struct Endpaper: View {
    let colorHex: String?

    var body: some View {
        let base = colorHex.flatMap(HexColor.init) ?? HexColor(DS.CoverPalette.hexes[1])!
        ZStack {
            base.color
            Color.black.opacity(0.28)
            VStack(spacing: DS.Spacing.xxs) {
                Text("Ex libris")
                    .font(.system(.caption, design: .serif, weight: .regular).italic())
                Rectangle().frame(width: 18, height: 0.5)
                Text("Booker")
                    .font(.system(.caption2, weight: .medium))
                    .textCase(.uppercase)
                    .tracking(1.5)
            }
            .foregroundStyle(Color.white.opacity(0.7))
        }
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: DS.Radius.cover, bottomLeadingRadius: DS.Radius.cover))
        .dynamicTypeSize(...DynamicTypeSize.large)
    }
}

// MARK: - Primera página

/// Lo que se lee al abrir el libro: estado, título y autor, como una portadilla.
struct FirstPage: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text(statusLine)
                .overlineStyle()
                .lineLimit(2)

            Text(book.title)
                .font(DS.Typography.bookTitle)
                .foregroundStyle(DS.Colors.inkPrimary)
                .lineLimit(5)
                .minimumScaleFactor(0.6)
                .accessibilityAddTraits(.isHeader)

            if !book.authors.isEmpty {
                Text(book.authorLine)
                    .font(DS.Typography.meta)
                    .foregroundStyle(DS.Colors.inkSecondary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)

            Rectangle()
                .fill(DS.Colors.accent)
                .frame(width: 24, height: 1)
                .accessibilityHidden(true)
        }
        .padding(.leading, DS.Spacing.l)
        .padding([.top, .trailing, .bottom], DS.Spacing.m)
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }

    private var statusLine: String {
        switch book.status {
        case .read:
            if let finished = book.dateFinished {
                return "Leído · \(finished.formatted(.dateTime.month(.wide).year()))"
            }
            return book.status.title
        case .reading, .toRead:
            return book.status.title
        }
    }
}
