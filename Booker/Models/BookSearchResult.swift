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
    /// Portada de Google Books a gran tamaño (unos 1000 × 1500 px).
    var googleCoverURL: URL?
    /// Portadas de Open Library, en orden de preferencia. Como mucho miden
    /// unos 300 × 500 px: son el último recurso.
    var openLibraryCoverURLs: [URL] = []

    /// Portadas para verla en grande, en orden de preferencia: la grande de
    /// Google, las de Open Library y, al final, la miniatura.
    var previewCoverURLs: [URL] {
        var urls: [URL] = []
        for url in [googleCoverURL].compactMap({ $0 }) + openLibraryCoverURLs + [thumbnailURL].compactMap({ $0 }) where !urls.contains(url) {
            urls.append(url)
        }
        return urls
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
