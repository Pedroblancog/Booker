import Foundation

/// Configuración que llega desde el Info.plist, que a su vez la toma de
/// `Booker/Config/Booker.xcconfig` (y de `Secrets.xcconfig`, si existe).
enum AppConfiguration {
    /// URL del backend propio. En Debug apunta a `wrangler dev` en el Mac.
    /// Vacía: sin Google Books (se busca solo en Open Library) y sin Descubrir.
    static let backendURL: URL? = infoValue("BookerBackendURL").flatMap(URL.init(string:))

    /// Token compartido con el backend (`APP_TOKEN` en el Worker). Opcional.
    static let backendToken: String? = infoValue("BookerBackendToken")

    static var backendHTTP: any HTTPClient {
        BackendHTTPClient(token: backendToken)
    }

    static func makeBookSearchService() -> any BookSearchService {
        let openLibrary = OpenLibrarySearchService()
        guard let backendURL else { return openLibrary }
        let google = GoogleBooksSearchService(baseURL: backendURL.appending(path: "books/v1"), http: backendHTTP)
        return FallbackBookSearchService(primary: google, fallback: openLibrary)
    }

    static func makeRecommendationService() -> any RecommendationService {
        guard let backendURL else { return UnconfiguredRecommendationService() }
        return BackendRecommendationService(baseURL: backendURL, http: backendHTTP)
    }

    private static func infoValue(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }
}
