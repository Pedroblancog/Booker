import SwiftUI

extension DS {
    /// Colores semánticos. Las variantes clara y oscura viven en `Assets.xcassets`.
    enum Colors {
        /// Fondo tipo papel, cálido en claro y casi negro en oscuro.
        static let canvas = Color(.canvas)
        /// Superficie de tarjetas: un punto más clara que el papel (y que el negro en oscuro).
        static let surface = Color(.surface)
        static let inkPrimary = Color(.inkPrimary)
        static let inkSecondary = Color(.inkSecondary)
        static let inkTertiary = Color(.inkTertiary)
        static let accent = Color(.accent)
    }

    /// Paleta para portadas generadas. Tonos apagados, de editorial.
    enum CoverPalette {
        static let hexes: [String] = [
            "#2F4A3A", // verde bosque
            "#7A2E2A", // burdeos
            "#1F3350", // azul marino
            "#B0823A", // ocre
            "#4A4E57", // pizarra
            "#5B3A55", // ciruela
            "#A65A3C", // terracota
            "#6F7F6A", // salvia
            "#E6DCCB", // hueso
        ]

        /// Siempre devuelve el mismo color para el mismo título,
        /// también entre ejecuciones (a diferencia de `hashValue`).
        static func hex(for seed: String) -> String {
            let hash = seed.unicodeScalars.reduce(UInt64(5381)) { ($0 &* 33) &+ UInt64($1.value) }
            return hexes[Int(hash % UInt64(hexes.count))]
        }
    }
}
