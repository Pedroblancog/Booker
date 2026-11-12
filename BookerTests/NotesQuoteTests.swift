import Foundation
import Testing
@testable import Booker

@MainActor
struct NotesQuoteTests {
    @Test func takesTheFirstSentence() {
        #expect(NotesQuoteView.excerpt(of: "Releer el capítulo de la lluvia. Y apuntar los nombres.") == "Releer el capítulo de la lluvia")
    }

    @Test func ignoresEmptyNotes() {
        #expect(NotesQuoteView.excerpt(of: nil) == nil)
        #expect(NotesQuoteView.excerpt(of: "   \n ") == nil)
    }

    @Test func shortensVeryLongSentences() throws {
        let long = String(repeating: "palabra ", count: 40)
        let excerpt = try #require(NotesQuoteView.excerpt(of: long))
        #expect(excerpt.count <= 140)
        #expect(excerpt.hasSuffix("…"))
    }

    @Test func picksOnlyBooksWithNotesAndRotatesByDay() throws {
        let context = try inMemoryContext()
        let a = Book(title: "A", authors: [], notes: "Primera nota.", dateAdded: .now.addingTimeInterval(-200))
        let b = Book(title: "B", authors: [])
        let c = Book(title: "C", authors: [], notes: "Segunda nota.", dateAdded: .now.addingTimeInterval(-100))
        [a, b, c].forEach(context.insert)

        let day1 = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1)))
        let day2 = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 2)))
        let first = try #require(NotesQuoteView.pick(from: [a, b, c], on: day1))
        let second = try #require(NotesQuoteView.pick(from: [a, b, c], on: day2))

        #expect(first.book.title != "B" && second.book.title != "B")
        #expect(first.book.title != second.book.title)
    }
}
