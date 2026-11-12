import Foundation
import SwiftData

/// Convierte un resultado de búsqueda en un `Book` guardado: descarga la
/// mejor portada, calcula su color dominante una sola vez y lo inserta.
@MainActor
struct BookImporter {
    let context: ModelContext
    let covers: any CoverImageProviding
    let colors: any DominantColorExtracting

    @discardableResult
    func add(_ result: BookSearchResult, as status: BookStatus, source: BookSource = .manual) async -> Book {
        let cover = await covers.bestCover(for: result)
        let book = Book(
            googleBooksID: result.googleBooksID,
            isbn: result.isbn,
            title: result.title,
            authors: result.authors,
            coverURL: cover?.url ?? result.thumbnailURL,
            coverImageData: cover?.data,
            status: status,
            source: source
        )
        await colors.assignDominantColorIfNeeded(to: book)
        context.insert(book)
        try? context.save()
        return book
    }
}

// MARK: - Duplicados

extension String {
    /// Para comparar títulos y autores sin tildes ni mayúsculas.
    var matchKey: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension BookSearchResult {
    /// ¿Está ya en la biblioteca? Por id de Google Books o, si no, por
    /// título y primer autor.
    func isInLibrary(_ books: [Book]) -> Bool {
        books.contains { book in
            if let googleBooksID, book.googleBooksID == googleBooksID { return true }
            return book.title.matchKey == title.matchKey
                && (book.authors.first?.matchKey ?? "") == (authors.first?.matchKey ?? "")
        }
    }
}
