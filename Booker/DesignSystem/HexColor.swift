import SwiftUI

/// Color sRGB expresado como `#RRGGBB`. Es el formato en que se guarda
/// `Book.dominantColorHex`.
struct HexColor: Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    init?(_ hex: String) {
        let digits = hex.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        red = Double((value >> 16) & 0xFF) / 255
        green = Double((value >> 8) & 0xFF) / 255
        blue = Double(value & 0xFF) / 255
    }

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue)
    }

    /// Luminancia relativa (WCAG), de 0 (negro) a 1 (blanco).
    var luminance: Double {
        func linear(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// Tinta legible sobre este color: papel claro o tinta oscura.
    var contrastingInk: Color {
        luminance > 0.45
            ? Color(.sRGB, red: 0.11, green: 0.10, blue: 0.09)
            : Color(.sRGB, red: 0.97, green: 0.95, blue: 0.92)
    }
}
