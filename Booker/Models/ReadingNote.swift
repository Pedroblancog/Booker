import Foundation
import SwiftData

/// Un comentario sobre lo leído, apuntado mientras se lee el libro.
@Model
final class ReadingNote {
    @Attribute(.unique) var id: UUID
    /// Página por la que ibas (opcional: a veces es una idea general).
    var page: Int?
    var text: String
    var dateAdded: Date
    var book: Book?

    init(id: UUID = UUID(), page: Int? = nil, text: String, dateAdded: Date = .now) {
        self.id = id
        self.page = page
        self.text = text
        self.dateAdded = dateAdded
    }
}

extension ReadingNote {
    /// "p. 142", o nada si no tiene página.
    var pageLabel: String? {
        page.map { "p. \($0)" }
    }

    var accessibilityLabel: String {
        page.map { "Página \($0): \(text)" } ?? text
    }

    /// En orden de lectura: por página y, sin página, al final; a igual
    /// página, el más antiguo primero.
    static func readingOrder(_ a: ReadingNote, _ b: ReadingNote) -> Bool {
        switch (a.page, b.page) {
        case let (x?, y?) where x != y: x < y
        case (nil, _?): false
        case (_?, nil): true
        default: a.dateAdded < b.dateAdded
        }
    }
}

extension Book {
    /// Los comentarios del libro, en orden de lectura.
    var sortedReadingNotes: [ReadingNote] {
        readingNotes.sorted(by: ReadingNote.readingOrder)
    }

    /// Añade un comentario al libro. Devuelve `nil` si el texto está vacío.
    @discardableResult
    func addReadingNote(page: Int?, text: String) -> ReadingNote? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let note = ReadingNote(page: page.flatMap { $0 > 0 ? $0 : nil }, text: trimmed)
        readingNotes.append(note)
        return note
    }

    /// Quita un comentario del libro y lo borra.
    func removeReadingNote(_ note: ReadingNote) {
        readingNotes.removeAll { $0.id == note.id }
        modelContext?.delete(note)
        try? modelContext?.save()
    }
}
