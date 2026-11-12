import Foundation
import SwiftData

/// Mejora las portadas de los libros ya guardados: busca una versión más
/// nítida para los que no tienen portada o la tienen pequeña, y la sustituye.
///
/// Va de uno en uno y con pausas, para no saturar la red ni las APIs.
/// Cada libro se intenta una sola vez (se recuerda en `UserDefaults`), así que
/// en los siguientes arranques no repite trabajo.
@MainActor
struct CoverUpgrader {
    let context: ModelContext
    let covers: any CoverImageProviding
    let colors: any DominantColorExtracting
    var defaults: UserDefaults = .standard
    /// Por debajo de este alto (en píxeles) se busca algo mejor.
    var minimumHeight = 1000
    var pause: Duration = .milliseconds(500)

    static let attemptedKey = "coverUpgrader.attempted.v1"

    func upgradeLibrary() async {
        let books = (try? context.fetch(FetchDescriptor<Book>(sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]))) ?? []
        var attempted = Set(defaults.stringArray(forKey: Self.attemptedKey) ?? [])

        for book in books where !attempted.contains(book.id.uuidString) && needsUpgrade(book) {
            guard !Task.isCancelled else { return }
            await upgrade(book)
            attempted.insert(book.id.uuidString)
            defaults.set(Array(attempted), forKey: Self.attemptedKey)
            try? await Task.sleep(for: pause)
        }
    }

    func needsUpgrade(_ book: Book) -> Bool {
        currentHeight(of: book) < minimumHeight
    }

    /// Devuelve `true` si encontró una portada más grande que la que había.
    @discardableResult
    func upgrade(_ book: Book) async -> Bool {
        let current = currentHeight(of: book)
        guard let cover = await covers.bestCover(title: book.title, authors: book.authors, candidates: candidates(for: book)),
              cover.pixelHeight > current, !book.isDeleted
        else { return false }

        book.coverImageData = cover.data
        book.coverURL = cover.url
        // El color de fondo del detalle sale de la portada: se recalcula.
        book.dominantColorHex = nil
        await colors.assignDominantColorIfNeeded(to: book)
        try? context.save()
        return true
    }

    /// Otras fuentes además de Apple Books: la portada de Google a gran tamaño
    /// (solo si la que había venía de Google: si el volumen no tiene portada,
    /// Google devuelve una imagen de "sin portada") y la de Open Library por ISBN.
    func candidates(for book: Book) -> [URL] {
        var urls: [URL] = []
        if let url = book.coverURL {
            urls.append(url.host()?.contains("books.google") == true
                ? GoogleBooksSearchService.sized(url, width: 1000, height: 1500)
                : url)
        }
        if let isbn = book.isbn {
            urls.append(URL(string: "https://covers.openlibrary.org/b/isbn/\(isbn)-L.jpg?default=false")!)
        }
        return urls
    }

    private func currentHeight(of book: Book) -> Int {
        book.coverImageData.flatMap(ImageDecoding.pixelSize(of:))?.height ?? 0
    }
}
