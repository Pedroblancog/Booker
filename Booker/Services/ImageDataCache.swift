import CryptoKit
import Foundation

protocol ImageDataLoading: Sendable {
    /// Los datos de una imagen válida, o `nil` si no hay imagen en esa URL.
    func imageData(for url: URL) async -> Data?
}

/// Caché de portadas en tres niveles: memoria, disco y red.
///
/// - Lo ya descargado no se vuelve a pedir, ni siquiera entre ejecuciones
///   (se guarda en Caches, que el sistema puede vaciar si falta espacio).
/// - Si dos vistas piden la misma URL a la vez, comparten una sola descarga.
/// - Las URL sin imagen (404, píxel de relleno) se recuerdan durante la
///   sesión para no insistir.
actor ImageDataCache: ImageDataLoading {
    static let shared = ImageDataCache()

    private let http: any HTTPClient
    private let directory: URL?
    private let memory: NSCache<NSURL, NSData> = {
        let cache = NSCache<NSURL, NSData>()
        cache.totalCostLimit = 40 * 1024 * 1024
        return cache
    }()
    private var inFlight: [URL: Task<Data?, Never>] = [:]
    private var missing: Set<URL> = []

    /// Con `directory` a `nil` la caché vive solo en memoria (útil en tests).
    init(http: any HTTPClient = URLSessionHTTPClient(), directory: URL? = ImageDataCache.defaultDirectory) {
        self.http = http
        self.directory = directory
    }

    static var defaultDirectory: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appending(path: "Covers", directoryHint: .isDirectory)
    }

    func imageData(for url: URL) async -> Data? {
        if let data = memory.object(forKey: url as NSURL) { return data as Data }
        if missing.contains(url) { return nil }
        if let task = inFlight[url] { return await task.value }

        let task = Task { await load(url) }
        inFlight[url] = task
        let data = await task.value
        inFlight[url] = nil

        if let data {
            memory.setObject(data as NSData, forKey: url as NSURL, cost: data.count)
        } else {
            missing.insert(url)
        }
        return data
    }

    /// Empieza a descargar en segundo plano lo que aún no esté en caché.
    nonisolated func prefetch(_ urls: [URL]) {
        for url in urls {
            Task(priority: .utility) { _ = await imageData(for: url) }
        }
    }

    private func load(_ url: URL) async -> Data? {
        let file = fileURL(for: url)
        if let file, let data = try? Data(contentsOf: file) { return data }

        guard let (data, response) = try? await http.get(url),
              (200..<300).contains(response.statusCode),
              let size = ImageDecoding.pixelSize(of: data),
              size.width > 10, size.height > 10
        else { return nil }

        if let file, let directory {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? data.write(to: file, options: .atomic)
        }
        return data
    }

    private func fileURL(for url: URL) -> URL? {
        let name = SHA256.hash(data: Data(url.absoluteString.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return directory?.appending(path: name)
    }
}
