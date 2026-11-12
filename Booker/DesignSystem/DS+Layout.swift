import CoreGraphics

extension DS {
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let xxxl: CGFloat = 72

        /// Margen lateral de las pantallas.
        static let gutter: CGFloat = 24
    }

    enum Radius {
        /// Esquinas de portada: apenas redondeadas, como un libro real.
        static let cover: CGFloat = 4
        /// Tarjetas grandes de Descubrir.
        static let card: CGFloat = 28
    }

    enum Layout {
        /// Proporción ancho/alto de una portada estándar.
        static let coverAspectRatio: CGFloat = 2.0 / 3.0
        static let gridColumnSpacing: CGFloat = 20
        static let gridRowSpacing: CGFloat = 36
    }
}
