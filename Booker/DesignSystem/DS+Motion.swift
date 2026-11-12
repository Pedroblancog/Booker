import SwiftUI

extension DS {
    enum Motion {
        /// Animación por defecto: muelle suave con un rebote mínimo.
        static let spring = Animation.spring(duration: 0.45, bounce: 0.15)
        /// Para cambios pequeños y rápidos (selección de filtros, estrellas).
        static let snappy = Animation.spring(duration: 0.3, bounce: 0.2)
    }
}
