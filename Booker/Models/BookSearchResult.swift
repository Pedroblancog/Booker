import Foundation

/// Un libro encontrado en Google Books u Open Library, aún no guardado.
struct BookSearchResult: Identifiable, Hashable, Sendable {
    enum Source: String, Sendable {
        case googleBooks
        case openLibrary
    }

    let id: String
    let source: Source
    var googleBooksID: String?
    var title: String
    var subtitle: String?
    var authors: [String]
    var isbn: String?
    var publishedYear: Int?

    /// Miniatura para listas.
    var thumbnailURL: URL?
    /// Portada de Google Books, la fuente principal.
    var googleCoverURL: URL?
    /// Portadas de Open Library, en orden de preferencia. Se usan si Google
    /// no tiene portada o la suya es de baja resolución.
    var openLibraryCoverURLs: [URL] = []

    /// Portada para verla en grande: la de Open Library a tamaño L si la hay,
    /// porque la miniatura de Google se ve borrosa a ese tamaño.
    var previewCoverURL: URL? {
        openLibraryCoverURLs.first ?? googleCoverURL ?? thumbnailURL
    }

    var authorLine: String {
        ListFormatter.localizedString(byJoining: authors)
    }

    var accessibilityLabel: String {
        authors.isEmpty ? title : "\(title), de \(authorLine)"
    }
}

extension BookSearchResult {
    /// Si un ISBN-10/13 aparece en el texto (con o sin guiones), lo devuelve limpio.
    static func isbn(in query: String) -> String? {
        let digits = query.uppercased().filter { $0.isNumber || $0 == "X" }
        let onlyIsbnCharacters = query.allSatisfy { $0.isNumber || $0 == "-" || $0 == " " || $0 == "X" || $0 == "x" }
        guard onlyIsbnCharacters, digits.count == 10 || digits.count == 13 else { return nil }
        return digits
    }

    /// Entre varios ISBN, prefiere un ISBN-13.
    static func preferredISBN(from candidates: [String]) -> String? {
        candidates.first { $0.count == 13 } ?? candidates.first
    }

    /// "1965" o "2006-04-30" → 1965.
    static func year(from publishedDate: String?) -> Int? {
        publishedDate.flatMap { Int($0.prefix(4)) }
    }
}
