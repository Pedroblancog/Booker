import SwiftUI

/// Una frase de tus notas destacada como cita de revista. Cambia cada día
/// entre los libros que tienen notas.
struct NotesQuoteView: View {
    let book: Book
    let quote: String

    var body: some View {
        NavigationLink(value: BookRoute(book: book, source: .quote)) {
            HStack(alignment: .top, spacing: DS.Spacing.m) {
                Rectangle()
                    .fill(DS.Colors.accent)
                    .frame(width: 1.5)

                VStack(alignment: .leading, spacing: DS.Spacing.s) {
                    Text("“\(quote)”")
                        .font(DS.Typography.pullQuote)
                        .foregroundStyle(DS.Colors.inkPrimary)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(3)

                    Text("De tus notas sobre \(book.title)")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.inkSecondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Abre el libro")
    }

    /// El libro y la frase del día: rota según el día del año, para que la
    /// cita cambie sin ser aleatoria en cada vistazo.
    static func pick(from books: [Book], on date: Date = .now) -> (book: Book, quote: String)? {
        let candidates = books
            .compactMap { book -> (Book, String)? in
                guard let quote = excerpt(of: book.notes) else { return nil }
                return (book, quote)
            }
            .sorted { $0.0.dateAdded < $1.0.dateAdded }
        guard !candidates.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 0
        return candidates[day % candidates.count]
    }

    /// La primera frase de la nota, recortada si es muy larga.
    static func excerpt(of notes: String?) -> String? {
        guard let text = notes?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        var sentence = text
        if let end = text.firstIndex(where: { ".!?\n".contains($0) }) {
            sentence = String(text[...end]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        sentence = sentence.trimmingCharacters(in: CharacterSet(charactersIn: ".\n "))
        if sentence.count > 140 {
            sentence = String(sentence.prefix(137)).trimmingCharacters(in: .whitespaces) + "…"
        }
        return sentence
    }
}
