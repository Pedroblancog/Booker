import Foundation

/// Estado de lectura de un libro.
enum BookStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case reading
    case read
    case toRead

    var id: String { rawValue }

    /// Nombre en singular, para el detalle ("Leído").
    var title: String {
        switch self {
        case .reading: "Leyendo"
        case .read: "Leído"
        case .toRead: "Pendiente"
        }
    }

    /// Nombre en plural, para filtros y listados ("Leídos").
    var pluralTitle: String {
        switch self {
        case .reading: "Leyendo"
        case .read: "Leídos"
        case .toRead: "Pendientes"
        }
    }
}
