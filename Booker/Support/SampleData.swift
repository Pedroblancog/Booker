import Foundation
import SwiftData

/// Libros de prueba para los #Preview y para las compilaciones de depuración.
/// No tienen portada: se muestran con el placeholder generado y funcionan sin conexión.
@MainActor
enum SampleData {
    static func makeBooks() -> [Book] {
        [
            Book(
                title: "Cien años de soledad",
                authors: ["Gabriel García Márquez"],
                status: .read,
                rating: 5,
                notes: "Releer el capítulo de la lluvia.",
                dateAdded: daysAgo(120),
                dateFinished: daysAgo(90)
            ),
            Book(
                title: "Pedro Páramo",
                authors: ["Juan Rulfo"],
                status: .read,
                rating: 5,
                dateAdded: daysAgo(80),
                dateFinished: daysAgo(70)
            ),
            Book(
                title: "Ficciones",
                authors: ["Jorge Luis Borges"],
                status: .read,
                rating: 4.5,
                dateAdded: daysAgo(60),
                dateFinished: daysAgo(45)
            ),
            Book(
                title: "La campana de cristal",
                authors: ["Sylvia Plath"],
                status: .read,
                rating: 3,
                dateAdded: daysAgo(40),
                dateFinished: daysAgo(30)
            ),
            Book(
                title: "Stoner",
                authors: ["John Williams"],
                status: .reading,
                dateAdded: daysAgo(14)
            ),
            Book(
                title: "Los detectives salvajes",
                authors: ["Roberto Bolaño"],
                status: .reading,
                dateAdded: daysAgo(9)
            ),
            Book(
                title: "Middlemarch",
                authors: ["George Eliot"],
                status: .toRead,
                dateAdded: daysAgo(5)
            ),
            Book(
                title: "El infinito en un junco",
                authors: ["Irene Vallejo"],
                status: .toRead,
                dateAdded: daysAgo(1),
                source: .recommendation
            ),
        ]
    }

    /// Inserta los libros de prueba solo si la biblioteca está vacía.
    static func seedIfEmpty(_ context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Book>())) ?? 0
        guard count == 0 else { return }
        let books = makeBooks()
        books.forEach(context.insert)
        if let detectives = books.first(where: { $0.title == "Los detectives salvajes" }) {
            detectives.addReadingNote(page: 17, text: "El realismo visceral: ¿existió de verdad?")
            detectives.addReadingNote(page: 214, text: "Empieza la segunda parte. Cambian las voces en cada capítulo.")
        }
        try? context.save()
    }

    /// Contenedor en memoria con los libros de prueba, para los #Preview.
    static let previewContainer: ModelContainer = {
        do {
            let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: Book.self, ReadingNote.self, configurations: configuration)
            seedIfEmpty(container.mainContext)
            return container
        } catch {
            fatalError("No se pudo crear el contenedor de previsualización: \(error)")
        }
    }()

    /// Un libro del contenedor de previsualización, para los #Preview del detalle.
    static func previewBook(titled title: String) -> Book {
        let descriptor = FetchDescriptor<Book>(predicate: #Predicate { $0.title == title })
        guard let book = try? previewContainer.mainContext.fetch(descriptor).first else {
            fatalError("No hay ningún libro de prueba titulado «\(title)»")
        }
        return book
    }

    private static func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
    }
}
