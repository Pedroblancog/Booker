import SwiftUI

/// Estado vacío de la Biblioteca, con un mensaje distinto para cada filtro.
struct LibraryEmptyState: View {
    let filter: LibraryFilter

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            Rectangle()
                .fill(DS.Colors.inkTertiary)
                .frame(width: 28, height: 1)

            Text(message)
                .font(DS.Typography.emptyState)
                .foregroundStyle(DS.Colors.inkPrimary)

            Text(hint)
                .font(DS.Typography.meta)
                .foregroundStyle(DS.Colors.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, DS.Spacing.xxl)
        .accessibilityElement(children: .combine)
    }

    private var message: String {
        switch filter {
        case .all: "Tu biblioteca espera su primer libro."
        case .status(.reading): "Ningún libro abierto ahora mismo."
        case .status(.read): "Aún no has terminado ningún libro."
        case .status(.toRead): "Tu lista de pendientes está vacía."
        }
    }

    private var hint: String {
        switch filter {
        case .all: "Busca un título para empezar tu registro."
        case .status(.reading): "Cuando empieces uno, aparecerá aquí."
        case .status(.read): "Los libros que termines se guardarán aquí, con tu puntuación."
        case .status(.toRead): "Guarda aquí lo que quieras leer después."
        }
    }
}

#Preview {
    LibraryEmptyState(filter: .status(.reading))
        .padding(DS.Spacing.gutter)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(DS.Colors.canvas)
}
