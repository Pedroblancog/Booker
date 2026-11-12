import SwiftUI

/// Una portada real, pintada a su proporción y con el acabado de un libro
/// impreso: la bisagra del lomo, una luz muy suave y un filo que separa las
/// portadas claras del papel. Es decorativa para VoiceOver.
struct CoverArtwork: View {
    let image: UIImage

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .aspectRatio(contentMode: .fill)
            .overlay { CoverFinish() }
            .accessibilityHidden(true)
    }

    /// Proporción ancho/alto de una portada. Se limita para que una imagen
    /// rara (un cuadrado, una tira) no rompa la composición: se recorta un poco.
    static func aspectRatio(width: CGFloat, height: CGFloat) -> CGFloat {
        guard width > 0, height > 0 else { return DS.Layout.coverAspectRatio }
        return min(max(width / height, DS.Layout.coverAspectRange.lowerBound), DS.Layout.coverAspectRange.upperBound)
    }

    static func aspectRatio(of image: UIImage) -> CGFloat {
        aspectRatio(width: image.size.width, height: image.size.height)
    }

    static func aspectRatio(of data: Data) -> CGFloat {
        guard let size = ImageDecoding.pixelSize(of: data) else { return DS.Layout.coverAspectRatio }
        return aspectRatio(width: CGFloat(size.width), height: CGFloat(size.height))
    }
}

/// El acabado se dibuja encima de la imagen, así que funciona igual con
/// cualquier portada.
private struct CoverFinish: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let spine = max(5, proxy.size.width * 0.055)

            ZStack(alignment: .leading) {
                // Luz que cae desde arriba a la izquierda, casi imperceptible.
                LinearGradient(
                    colors: [.white.opacity(0.07), .clear, .black.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Lomo: el canto en sombra, el surco de la bisagra y su brillo.
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.24), location: 0),
                        .init(color: .black.opacity(0.04), location: 0.28),
                        .init(color: .white.opacity(0.18), location: 0.45),
                        .init(color: .black.opacity(0.12), location: 0.62),
                        .init(color: .black.opacity(0.03), location: 0.8),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: spine)
            }
        }
        .overlay {
            // En claro, un filo de tinta casi invisible para las portadas blancas.
            RoundedRectangle(cornerRadius: DS.Radius.cover, style: .continuous)
                .strokeBorder(.black.opacity(colorScheme == .dark ? 0 : 0.08), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }
}
