import Foundation

/// Búsqueda en Google Books (`/books/v1/volumes`).
///
/// Google Books exige una clave de API, y la clave nunca va en la app:
/// `baseURL` apunta al backend propio, que añade la clave y reenvía la
/// petición a `https://www.googleapis.com/books/v1`.
struct GoogleBooksSearchService: BookSearchService {
    let baseURL: URL
    var http: any HTTPClient = URLSessionHTTPClient()
    var limit = 20

    func search(_ query: String) async throws -> [BookSearchResult] {
        let response = try await http.getJSON(VolumesResponse.self, from: searchURL(for: query))
        return (response.items ?? []).compactMap(Self.result(from:))
    }

    func searchURL(for query: String) -> URL {
        var components = URLComponents(url: baseURL.appending(path: "volumes"), resolvingAgainstBaseURL: false)!
        let q = BookSearchResult.isbn(in: query).map { "isbn:\($0)" } ?? query
        components.queryItems = [
            URLQueryItem(name: "q", value: q),
            URLQueryItem(name: "maxResults", value: String(limit)),
            URLQueryItem(name: "printType", value: "books"),
        ]
        return components.url!
    }

    static func result(from volume: VolumesResponse.Volume) -> BookSearchResult? {
        let info = volume.volumeInfo
        guard let title = info.title, !title.isEmpty else { return nil }
        let identifiers = info.industryIdentifiers ?? []
        let isbn13 = identifiers.first { $0.type == "ISBN_13" }?.identifier
        let isbn10 = identifiers.first { $0.type == "ISBN_10" }?.identifier
        let isbn = isbn13 ?? isbn10
        let thumbnail = (info.imageLinks?.thumbnail ?? info.imageLinks?.smallThumbnail).flatMap(secureCoverURL)

        return BookSearchResult(
            id: "gb:\(volume.id)",
            source: .googleBooks,
            googleBooksID: volume.id,
            title: title,
            subtitle: info.subtitle,
            authors: info.authors ?? [],
            isbn: isbn,
            publishedYear: BookSearchResult.year(from: info.publishedDate),
            thumbnailURL: thumbnail,
            googleCoverURL: thumbnail,
            openLibraryCoverURLs: isbn.map {
                [URL(string: "https://covers.openlibrary.org/b/isbn/\($0)-L.jpg?default=false")!]
            } ?? []
        )
    }

    /// Google devuelve las portadas por `http` y con un efecto de página
    /// doblada (`edge=curl`). Se pasan a `https` (iOS bloquea `http`) y sin efecto.
    static func secureCoverURL(_ string: String) -> URL? {
        guard var components = URLComponents(string: string) else { return nil }
        components.scheme = "https"
        components.queryItems = components.queryItems?.filter { $0.name != "edge" }
        return components.url
    }

    // Los nombres siguen el JSON de Google Books.
    struct VolumesResponse: Decodable {
        let items: [Volume]?

        struct Volume: Decodable {
            let id: String
            let volumeInfo: VolumeInfo
        }

        struct VolumeInfo: Decodable {
            let title: String?
            let subtitle: String?
            let authors: [String]?
            let publishedDate: String?
            let industryIdentifiers: [IndustryIdentifier]?
            let imageLinks: ImageLinks?
        }

        struct IndustryIdentifier: Decodable {
            let type: String
            let identifier: String
        }

        struct ImageLinks: Decodable {
            let smallThumbnail: String?
            let thumbnail: String?
        }
    }
}
