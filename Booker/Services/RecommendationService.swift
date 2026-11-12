import Foundation

/// Un libro bien puntuado que se envía al recomendador.
struct FavoriteBook: Codable, Equatable, Sendable {
    let title: String
    let authors: [String]
    let rating: Double
}

/// Lo que propone el LLM, aún sin verificar.
struct RecommendationCandidate: Codable, Equatable, Sendable {
    let title: String
    let author: String
    let reason: String
}

enum RecommendationError: Error, Equatable {
    /// La app no tiene backend configurado, o el backend no tiene clave del LLM.
    case notConfigured
    case offline
    case unavailable
}

protocol RecommendationService: Sendable {
    func candidates(for favorites: [FavoriteBook], excluding: [String], count: Int) async throws -> [RecommendationCandidate]
}

/// Pide recomendaciones a `POST /recommendations` del backend propio.
/// El LLM se llama siempre desde el servidor; la app no conoce ninguna clave.
struct BackendRecommendationService: RecommendationService {
    let baseURL: URL
    var http: any HTTPClient = URLSessionHTTPClient()

    private struct RequestBody: Encodable {
        let favorites: [FavoriteBook]
        let exclude: [String]
        let count: Int
    }

    private struct ResponseBody: Decodable {
        let recommendations: [RecommendationCandidate]
    }

    func candidates(for favorites: [FavoriteBook], excluding: [String], count: Int) async throws -> [RecommendationCandidate] {
        var request = URLRequest(url: baseURL.appending(path: "recommendations"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 90
        request.httpBody = try JSONEncoder().encode(RequestBody(favorites: favorites, exclude: excluding, count: count))

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await http.send(request)
        } catch {
            if case BookSearchError.offline = BookSearchError.from(error) { throw RecommendationError.offline }
            if error is CancellationError || (error as? URLError)?.code == .cancelled { throw CancellationError() }
            throw RecommendationError.unavailable
        }

        switch response.statusCode {
        case 200..<300:
            guard let body = try? JSONDecoder().decode(ResponseBody.self, from: data) else {
                throw RecommendationError.unavailable
            }
            return body.recommendations
        case 401, 503:
            throw RecommendationError.notConfigured
        default:
            throw RecommendationError.unavailable
        }
    }
}

/// Se usa cuando la app no tiene backend: Descubrir lo explica en pantalla.
struct UnconfiguredRecommendationService: RecommendationService {
    func candidates(for favorites: [FavoriteBook], excluding: [String], count: Int) async throws -> [RecommendationCandidate] {
        throw RecommendationError.notConfigured
    }
}
