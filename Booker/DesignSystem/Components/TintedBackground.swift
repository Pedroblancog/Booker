import SwiftUI

/// Velo muy sutil del color de una portada que se desvanece hacia abajo.
/// En oscuro es algo más intenso, porque sobre negro los tonos apagados
/// apenas se perciben.
struct TintGradient: View {
    let colorHex: String?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            if let tint = colorHex.flatMap(HexColor.init)?.color {
                let isDark = colorScheme == .dark
                LinearGradient(
                    stops: [
                        .init(color: tint.opacity(isDark ? 0.38 : 0.24), location: 0),
                        .init(color: tint.opacity(isDark ? 0.14 : 0.08), location: 0.45),
                        .init(color: tint.opacity(0), location: 0.85),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .transition(.opacity)
            }
        }
        .animation(DS.Motion.spring, value: colorHex)
    }
}

/// Fondo de papel de una pantalla, teñido con el color de la portada.
struct TintedBackground: View {
    let colorHex: String?

    var body: some View {
        ZStack {
            DS.Colors.canvas
            TintGradient(colorHex: colorHex)
        }
        .ignoresSafeArea()
    }
}
