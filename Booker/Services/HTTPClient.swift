import Foundation

/// Única puerta de salida a la red. Los servicios dependen de este protocolo
/// y no de `URLSession`, así que en los tests se sustituye por un mock.
protocol HTTPClient: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

extension HTTPClient {
    func get(_ url: URL) async throws -> (Data, HTTPURLResponse) {
        try await send(URLRequest(url: url))
    }
}

struct URLSessionHTTPClient: HTTPClient {
    var session: URLSession = .shared

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var request = request
        // Open Library pide identificar la app en las peticiones.
        request.setValue("Booker/0.1 (iOS; registro personal de lectura)", forHTTPHeaderField: "User-Agent")
        do {
            return try await perform(request)
        } catch let error as URLError where error.code == .networkConnectionLost {
            // URLSession reutiliza conexiones HTTP/3 inactivas que a veces ya han
            // muerto en silencio. Un único reintento abre una conexión nueva.
            return try await perform(request)
        }
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }
}

/// Peticiones al backend propio: añade el token de la app si está configurado.
/// El token solo evita usos casuales del backend; las claves de API de
/// verdad (Anthropic, Google) viven en el servidor.
struct BackendHTTPClient: HTTPClient {
    var base: any HTTPClient = URLSessionHTTPClient()
    let token: String?

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var request = request
        if let token { request.setValue(token, forHTTPHeaderField: "X-Booker-Token") }
        return try await base.send(request)
    }
}
