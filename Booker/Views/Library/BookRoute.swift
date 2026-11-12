import Foundation

/// Navegación al detalle de un libro. Un mismo libro puede abrirse desde
/// varios sitios (la cuadrícula, "Leyendo ahora", la cita del día), y cada
/// uno es un origen distinto para la animación de abrir el libro.
struct BookRoute: Hashable {
    let book: Book
    let source: Source

    enum Source: String, Hashable {
        case grid
        case readingNow
        case quote
    }

    /// Identifica la portada desde la que se abre el libro.
    var transitionID: String { Self.transitionID(book, source) }

    static func transitionID(_ book: Book, _ source: Source) -> String {
        "\(source.rawValue)-\(book.id.uuidString)"
    }
}
