import Foundation

/// Busca la portada de un libro por título y autor en otra fuente.
protocol CoverLookup: Sendable {
    func coverURL(title: String, author: String?) async -> URL?
}

/// Portadas de Apple Books a través de la iTunes Search API (pública, sin clave).
///
/// Son las portadas de las ediciones digitales de las editoriales: limpias,
/// sin escanear y a gran resolución. La URL de la miniatura (`100x100bb`)
/// admite cualquier tamaño; a `1600x1600bb` llega una imagen de unos
/// 1000 × 1600 px, que se ve nítida incluso a pantalla completa.
///
/// Las condiciones de esta API piensan en promocionar la tienda: para un uso
/// personal no hay problema, pero habría que revisarlas antes de publicar la app.
struct AppleBooksCoverLookup: CoverLookup {
    var http: any HTTPClient = URLSessionHTTPClient()
    /// Tiendas en las que buscar, en orden. La del dispositivo primero.
    var storefronts: [String] = Self.defaultStorefronts
    /// Lado mayor pedido, en píxeles.
    var artworkSize = 1600

    /// Lo ya buscado en esta sesión (también las búsquedas sin resultado).
    var memo: LookupMemo? = .shared

    func coverURL(title: String, author: String?) async -> URL? {
        let key = "\(title.titleKey)|\(author?.matchKey ?? "")|\(artworkSize)"
        if let memo, let known = await memo.value(for: key) { return known }
        let url = await search(title: title, author: author)
        if !Task.isCancelled { await memo?.store(url, for: key) }
        return url
    }

    private func search(title: String, author: String?) async -> URL? {
        for country in storefronts {
            guard !Task.isCancelled else { return nil }
            guard let response = try? await http.getJSON(SearchResponse.self, from: searchURL(title: title, author: author, country: country))
            else { continue }
            if let url = Self.bestArtwork(in: response.results, title: title, author: author, size: artworkSize) {
                return url
            }
        }
        return nil
    }

    func searchURL(title: String, author: String?, country: String) -> URL {
        var components = URLComponents(string: "https://itunes.apple.com/search")!
        // El título sin subtítulo encuentra más ediciones.
        let mainTitle = title.split(separator: ":", maxSplits: 1).first.map(String.init) ?? title
        components.queryItems = [
            URLQueryItem(name: "term", value: [mainTitle, author].compactMap { $0 }.joined(separator: " ")),
            URLQueryItem(name: "media", value: "ebook"),
            URLQueryItem(name: "entity", value: "ebook"),
            URLQueryItem(name: "country", value: country),
            URLQueryItem(name: "limit", value: "8"),
        ]
        return components.url!
    }

    /// La primera edición cuyo título y autor coinciden, prefiriendo el título exacto.
    static func bestArtwork(in results: [SearchResponse.Item], title: String, author: String?, size: Int) -> URL? {
        let matching = results.filter { item in
            guard let name = item.trackName, item.artworkUrl100 != nil else { return false }
            // Sin autor, solo vale el título exacto: "Stoner" no es "Stoner: guía de lectura".
            if author?.isEmpty ?? true, !BookMatching.isExactTitle(title, name) { return false }
            return BookMatching.matches(title: title, author: author, candidateTitle: name,
                                        candidateAuthors: item.artistName.map { [$0] } ?? [])
        }
        let best = matching.first { BookMatching.isExactTitle(title, $0.trackName ?? "") } ?? matching.first
        return best?.artworkUrl100.flatMap { artworkURL($0, size: size) }
    }

    /// `…/1028742243.jpg/100x100bb.jpg` → `…/1028742243.jpg/1600x1600bb.jpg`.
    static func artworkURL(_ thumbnail: String, size: Int) -> URL? {
        guard let url = URL(string: thumbnail), url.lastPathComponent.contains("bb.") else { return nil }
        let ext = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
        return url.deletingLastPathComponent().appending(path: "\(size)x\(size)bb.\(ext)")
    }

    /// La tienda de la región del dispositivo y, después, la española y la estadounidense.
    static var defaultStorefronts: [String] {
        var countries: [String] = []
        for country in [Locale.current.region?.identifier.lowercased(), "es", "us"].compactMap({ $0 })
        where country.count == 2 && !countries.contains(country) {
            countries.append(country)
        }
        return countries
    }

    struct SearchResponse: Decodable {
        let results: [Item]

        struct Item: Decodable {
            let trackName: String?
            let artistName: String?
            let artworkUrl100: String?
        }
    }
}

/// Memoria de búsquedas de portada: evita repetir la consulta al abrir la
/// ficha de un resultado y al añadirlo después.
actor LookupMemo {
    static let shared = LookupMemo()
    private var entries: [String: URL?] = [:]

    func value(for key: String) -> URL?? {
        entries[key]
    }

    func store(_ url: URL?, for key: String) {
        entries[key] = .some(url)
    }
}
