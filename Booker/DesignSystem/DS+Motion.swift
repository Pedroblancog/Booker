import SwiftUI

extension DS {
    enum Motion {
        /// Animación por defecto: muelle suave con un rebote mínimo.
        static let spring = Animation.spring(duration: 0.45, bounce: 0.15)
        /// Para cambios pequeños y rápidos (selección de filtros, estrellas).
        static let snappy = Animation.spring(duration: 0.3, bounce: 0.2)
        /// Con "Reducir movimiento" activado: un fundido corto, sin rebote.
        static let reduced = Animation.easeInOut(duration: 0.2)
    }
}

extension AnyTransition {
    /// Entrada y salida de elementos de una lista o cuadrícula: aparece
    /// creciendo un poco, o solo fundiendo si se ha pedido reducir movimiento.
    static func appear(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.94))
    }
}

/// Latido suave para los estados de carga. Con "Reducir movimiento" queda quieto.
private struct LoadingPulse: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content.opacity(0.75)
        } else {
            content.phaseAnimator([false, true]) { content, isDim in
                content.opacity(isDim ? 0.45 : 1)
            } animation: { _ in
                .easeInOut(duration: 0.9)
            }
        }
    }
}

extension View {
    func loadingPulse() -> some View {
        modifier(LoadingPulse())
    }
}
