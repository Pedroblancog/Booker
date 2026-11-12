import SwiftUI

/// Portada generada para libros sin imagen: fondo de color, un lomo sombreado
/// a la izquierda y el título en serif, como una edición en rústica sobria.
///
/// El texto se dimensiona según el ancho de la portada, no con Dynamic Type,
/// porque forma parte de la ilustración. Por eso se oculta a VoiceOver;
/// la etiqueta accesible la pone quien contiene la portada.
struct CoverPlaceholderView: View {
    let title: String
    let author: String?
    let colorHex: String

    var body: some View {
        let base = HexColor(colorHex) ?? HexColor(DS.CoverPalette.hexes[0])!
        let ink = base.contrastingInk

        GeometryReader { proxy in
            let width = proxy.size.width

            ZStack(alignment: .topLeading) {
                base.color

                // Luz suave de arriba a abajo para quitar el aspecto plano.
                LinearGradient(
                    colors: [.white.opacity(0.10), .clear, .black.opacity(0.16)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Lomo.
                LinearGradient(
                    colors: [.black.opacity(0.22), .black.opacity(0.04), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: width * 0.07)

                VStack(alignment: .leading, spacing: width * 0.06) {
                    Rectangle()
                        .fill(ink.opacity(0.45))
                        .frame(width: width * 0.12, height: 1)

                    Text(title)
                        .font(.system(size: width * 0.12, weight: .regular, design: .serif))
                        .foregroundStyle(ink)
                        .lineLimit(5)
                        .minimumScaleFactor(0.6)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)

                    if let author, !author.isEmpty {
                        Text(author)
                            .font(.system(size: width * 0.052, weight: .light))
                            .textCase(.uppercase)
                            .tracking(width * 0.006)
                            .foregroundStyle(ink.opacity(0.75))
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                    }
                }
                .padding(.leading, width * 0.15)
                .padding([.top, .trailing, .bottom], width * 0.1)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview("Placeholders") {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 20)], spacing: 28) {
        ForEach(DS.CoverPalette.hexes, id: \.self) { hex in
            CoverPlaceholderView(title: "El infinito en un junco", author: "Irene Vallejo", colorHex: hex)
                .aspectRatio(DS.Layout.coverAspectRatio, contentMode: .fit)
                .coverStyle()
        }
    }
    .padding(DS.Spacing.gutter)
    .frame(maxHeight: .infinity)
    .background(DS.Colors.canvas)
}
