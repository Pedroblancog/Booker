import Foundation

protocol BookSearchService: Sendable {
    func search(_ query: String) async throws -> [BookSearchResult]
}

enum BookSearchError: Error, Equatable {
    case offline
    case server(statusCode: Int)
    case invalidResponse

    /// Traduce errores de red de `URLSession` a algo que la interfaz sabe explicar.
    static func from(_ error: Error) -> Error {
        if error is CancellationError { return error }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cancelled: return CancellationError()
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .timedOut,
                 .cannotFindHost, .cannotConnectToHost:
                return BookSearchError.offline
            default: return BookSearchError.invalidResponse
            }
        }
        if error is DecodingError { return BookSearchError.invalidResponse }
        return error
    }
}

/// Usa el servicio principal y, si falla por cualquier motivo salvo una
/// cancelación (backend caído, sin clave de Google, cuota agotada…),
/// el alternativo. Si también falla, se informa del error del alternativo.
struct FallbackBookSearchService: BookSearchService {
    let primary: any BookSearchService
    let fallback: any BookSearchService

    func search(_ query: String) async throws -> [BookSearchResult] {
        do {
            return try await primary.search(query)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return try await fallback.search(query)
        }
    }
}

extension HTTPClient {
    /// Descarga y decodifica JSON, comprobando el código de estado.
    func getJSON<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        do {
            let (data, response) = try await get(url)
            guard (200..<300).contains(response.statusCode) else {
                throw BookSearchError.server(statusCode: response.statusCode)
            }
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw BookSearchError.from(error)
        }
    }
}
