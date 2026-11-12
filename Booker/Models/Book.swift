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
    /// 1–5, solo para libros leídos. Se modifica con `setRating(_:)`.
    private(set) var rating: Int?
    var notes: String?

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
        rating: Int? = nil,
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
        self.rating = status == .read ? Book.clamped(rating) : nil
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
                rating = nil
                dateFinished = nil
            }
        }
    }

    var source: BookSource {
        get { BookSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    /// Solo se aplica a libros leídos. Los valores se ajustan al rango 1–5.
    func setRating(_ value: Int?) {
        guard status == .read else { return }
        rating = Book.clamped(value)
    }

    private static func clamped(_ value: Int?) -> Int? {
        value.map { min(max($0, 1), 5) }
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
        return "\(status.title), \(rating) de 5 estrellas"
    }
}
