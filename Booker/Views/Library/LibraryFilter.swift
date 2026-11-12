import Foundation

/// Filtro de la Biblioteca: todos los libros o uno de los estados.
enum LibraryFilter: Hashable, Identifiable, CaseIterable {
    case all
    case status(BookStatus)

    static var allCases: [LibraryFilter] {
        [.all] + BookStatus.allCases.map(LibraryFilter.status)
    }

    var id: String {
        switch self {
        case .all: "all"
        case .status(let status): status.rawValue
        }
    }

    var title: String {
        switch self {
        case .all: "Todos"
        case .status(let status): status.pluralTitle
        }
    }

    func includes(_ book: Book) -> Bool {
        switch self {
        case .all: true
        case .status(let status): book.status == status
        }
    }
}
