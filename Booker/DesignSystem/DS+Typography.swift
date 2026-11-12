import SwiftUI

extension DS {
    /// Todas las fuentes parten de un `TextStyle`, así que escalan con Dynamic Type.
    /// Serif para títulos de libros; SF Pro ligera para metadatos y menús.
    enum Typography {
        static let display = Font.system(.largeTitle, design: .serif, weight: .regular)
        static let bookTitle = Font.system(.title2, design: .serif, weight: .regular)
        static let bookTitleCompact = Font.system(.headline, design: .serif, weight: .regular)
        static let emptyState = Font.system(.title3, design: .serif, weight: .regular).italic()

        static let overline = Font.system(.caption, weight: .medium)
        static let meta = Font.system(.subheadline, weight: .light)
        static let menu = Font.system(.subheadline, weight: .light)
        static let menuSelected = Font.system(.subheadline, weight: .regular)
        static let body = Font.system(.body, weight: .light)
    }
}

extension View {
    /// Rótulo pequeño en versalitas espaciadas, sobre títulos.
    func overlineStyle() -> some View {
        font(DS.Typography.overline)
            .textCase(.uppercase)
            .tracking(1.6)
            .foregroundStyle(DS.Colors.inkTertiary)
    }
}
