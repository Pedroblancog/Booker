import SwiftUI

/// Da a una portada su aspecto de objeto que flota: esquinas suaves,
/// una sombra de contacto corta y otra ambiental amplia y difusa.
///
/// En oscuro la sombra apenas se ve sobre el fondo negro, así que se
/// refuerza y se añade un filo de luz casi imperceptible que separa la portada del fondo.
private struct CoverStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let isDark = colorScheme == .dark
        let shape = RoundedRectangle(cornerRadius: DS.Radius.cover, style: .continuous)

        content
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(.white.opacity(isDark ? 0.08 : 0), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(isDark ? 0.40 : 0.08), radius: 1.5, y: 1)
            .shadow(color: .black.opacity(isDark ? 0.55 : 0.18), radius: 18, y: 14)
    }
}

extension View {
    func coverStyle() -> some View {
        modifier(CoverStyle())
    }
}
