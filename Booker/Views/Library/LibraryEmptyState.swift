import SwiftUI

/// Estado vacío de la Biblioteca, con un mensaje distinto para cada filtro.
struct LibraryEmptyState: View {
    let filter: LibraryFilter

    var body: some View {
        EditorialMessageView(title: title, message: message)
    }

    private var title: String {
        switch filter {
        case .all: "Tu biblioteca espera su primer libro."
        case .status(.reading): "Ningún libro abierto ahora mismo."
        case .status(.read): "Aún no has terminado ningún libro."
        case .status(.toRead): "Tu lista de pendientes está vacía."
        }
    }

    private var message: String {
        switch filter {
        case .all: "Busca un título en la pestaña Buscar para empezar tu registro."
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
