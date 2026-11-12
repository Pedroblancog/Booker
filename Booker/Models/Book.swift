import Foundation
import SwiftData

@Model
final class Book {
    @Attribute(.unique) var id: UUID
    var googleBooksID: String?
    var isbn: String?

    var title: String
    var authors: [String]

    var coverURL: URL?
    /// Caché local de la portada. Se guarda fuera de la base de datos.
    @Attribute(.externalStorage) var coverImageData: Data?
    /// Color dominante de la portada (`#RRGGBB`), calculado una sola vez al guardar.
    var dominantColorHex: String?

    /// Se persiste el valor bruto para poder filtrar con `#Predicate`.
    /// Usa `status` desde el resto de la app.
    var statusRaw: String
    /// De 0,5 a 5 en pasos de media estrella, solo para libros leídos.
    /// Se modifica con `setRating(_:)`. Tiene otro nombre que el `rating`
    /// entero de la versión anterior para que SwiftData migre sin pedir un plan.
    private(set) var starRating: Double?
    /// La conclusión que se escribe al terminarlo (antes, notas libres).
    var notes: String?
    /// Comentarios apuntados mientras se lee. Se borran con el libro.
    @Relationship(deleteRule: .cascade, inverse: \ReadingNote.book)
    var readingNotes: [ReadingNote] = []

    var dateAdded: Date
    var dateFinished: Date?

    /// Ver `statusRaw`.
    var sourceRaw: String

    init(
        id: UUID = UUID(),
        googleBooksID: String? = nil,
        isbn: String? = nil,
        title: String,
        authors: [String],
        coverURL: URL? = nil,
        coverImageData: Data? = nil,
        dominantColorHex: String? = nil,
        status: BookStatus = .toRead,
        rating: Double? = nil,
        notes: String? = nil,
        dateAdded: Date = .now,
        dateFinished: Date? = nil,
        source: BookSource = .manual
    ) {
        self.id = id
        self.googleBooksID = googleBooksID
        self.isbn = isbn
        self.title = title
        self.authors = authors
        self.coverURL = coverURL
        self.coverImageData = coverImageData
        self.dominantColorHex = dominantColorHex
        self.statusRaw = status.rawValue
        self.starRating = status == .read ? Book.normalized(rating) : nil
        self.notes = notes
        self.dateAdded = dateAdded
        self.dateFinished = status == .read ? (dateFinished ?? dateAdded) : nil
        self.sourceRaw = source.rawValue
    }
}

// MARK: - Estado y puntuación

extension Book {
    /// Al salir de "leído" se borran la puntuación y la fecha de fin;
    /// al entrar, se fija la fecha de fin si no la tenía.
    var status: BookStatus {
        get { BookStatus(rawValue: statusRaw) ?? .toRead }
        set {
            statusRaw = newValue.rawValue
            if newValue == .read {
                dateFinished = dateFinished ?? .now
            } else {
                starRating = nil
                dateFinished = nil
            }
        }
    }

    var rating: Double? { starRating }

    var source: BookSource {
        get { BookSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    /// Solo se aplica a libros leídos. Redondea a la media estrella más
    /// cercana y ajusta al rango 0,5–5.
    func setRating(_ value: Double?) {
        guard status == .read else { return }
        starRating = Book.normalized(value)
    }

    private static func normalized(_ value: Double?) -> Double? {
        value.map { min(max(($0 * 2).rounded() / 2, 0.5), 5) }
    }
}

// MARK: - Presentación

extension Book {
    /// "Autor A y Autor B", según el idioma del dispositivo.
    var authorLine: String {
        ListFormatter.localizedString(byJoining: authors)
    }

    /// Texto para VoiceOver: "Título, de Autor".
    var accessibilityLabel: String {
        authors.isEmpty ? title : "\(title), de \(authorLine)"
    }

    var accessibilityStatus: String {
        guard status == .read, let rating else { return status.title }
        return "\(status.title), \(Book.formattedRating(rating)) de 5 estrellas"
    }

    /// "4" o "3,5", según el idioma del dispositivo.
    static func formattedRating(_ rating: Double) -> String {
        rating.formatted(.number.precision(.fractionLength(0...1)))
    }
}
