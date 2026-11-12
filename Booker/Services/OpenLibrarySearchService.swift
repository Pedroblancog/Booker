import Foundation

/// Búsqueda en Open Library (`/search.json`). No necesita clave.
/// Documentación: https://openlibrary.org/dev/docs/api/search
struct OpenLibrarySearchService: BookSearchService {
    var http: any HTTPClient = URLSessionHTTPClient()
    var limit = 20

    func search(_ query: String) async throws -> [BookSearchResult] {
        let response = try await http.getJSON(SearchResponse.self, from: searchURL(for: query))
        return response.docs.compactMap(Self.result(from:))
    }

    func searchURL(for query: String) -> URL {
        var components = URLComponents(string: "https://openlibrary.org/search.json")!
        let q = BookSearchResult.isbn(in: query).map { "isbn:\($0)" } ?? query
        components.queryItems = [
            URLQueryItem(name: "q", value: q),
            URLQueryItem(name: "limit", value: String(limit)),
            // Prefiere ediciones en el idioma del dispositivo al elegir título.
            URLQueryItem(name: "lang", value: Locale.current.language.languageCode?.identifier ?? "es"),
            URLQueryItem(name: "fields", value: "key,title,subtitle,author_name,first_publish_year,isbn,cover_i"),
        ]
        return components.url!
    }

    static func result(from doc: SearchResponse.Doc) -> BookSearchResult? {
        guard let title = doc.title, !title.isEmpty else { return nil }
        let isbn = BookSearchResult.preferredISBN(from: doc.isbn ?? [])

        // Las portadas por id no tienen límite de peticiones; las de ISBN sí
        // (unas 100 cada 5 minutos por IP), así que van en segundo lugar.
        var covers: [URL] = []
        if let coverID = doc.cover_i {
            covers.append(URL(string: "https://covers.openlibrary.org/b/id/\(coverID)-L.jpg")!)
        }
        if let isbn {
            covers.append(URL(string: "https://covers.openlibrary.org/b/isbn/\(isbn)-L.jpg?default=false")!)
        }

        return BookSearchResult(
            id: "ol:\(doc.key)",
            source: .openLibrary,
            title: title,
            subtitle: doc.subtitle,
            authors: doc.author_name ?? [],
            isbn: isbn,
            publishedYear: doc.first_publish_year,
            thumbnailURL: doc.cover_i.flatMap { URL(string: "https://covers.openlibrary.org/b/id/\($0)-M.jpg") },
            openLibraryCoverURLs: covers
        )
    }

    // Los nombres siguen el JSON de Open Library.
    struct SearchResponse: Decodable {
        let docs: [Doc]

        struct Doc: Decodable {
            let key: String
            let title: String?
            let subtitle: String?
            let author_name: [String]?
            let first_publish_year: Int?
            let isbn: [String]?
            let cover_i: Int?
        }
    }
}
