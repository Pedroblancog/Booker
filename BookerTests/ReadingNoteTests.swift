import Foundation
import SwiftData
import Testing
@testable import Booker

@MainActor
struct ReadingNoteTests {
    @Test func sortsByPageWithPagelessNotesLast() throws {
        let context = try inMemoryContext()
        let book = Book(title: "Stoner", authors: [], status: .reading)
        context.insert(book)
        book.addReadingNote(page: 120, text: "Edith")
        book.addReadingNote(page: nil, text: "Idea general")
        book.addReadingNote(page: 15, text: "Archer Sloane")

        #expect(book.sortedReadingNotes.map(\.text) == ["Archer Sloane", "Edith", "Idea general"])
    }

    @Test func ignoresEmptyTextAndInvalidPages() throws {
        let context = try inMemoryContext()
        let book = Book(title: "Stoner", authors: [], status: .reading)
        context.insert(book)

        #expect(book.addReadingNote(page: 3, text: "   \n") == nil)
        let note = try #require(book.addReadingNote(page: 0, text: "  Sin página  "))
        #expect(note.page == nil)
        #expect(note.text == "Sin página")
        #expect(note.pageLabel == nil)
        #expect(book.readingNotes.count == 1)
    }

    @Test func labelsThePage() {
        let note = ReadingNote(page: 142, text: "Lluvia")
        #expect(note.pageLabel == "p. 142")
        #expect(note.accessibilityLabel == "Página 142: Lluvia")
    }

    @Test func deletingTheBookRemovesItsNotes() throws {
        let context = try inMemoryContext()
        let book = Book(title: "Stoner", authors: [], status: .reading)
        context.insert(book)
        book.addReadingNote(page: 1, text: "Primera")
        try context.save()

        context.delete(book)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<ReadingNote>()) == 0)
    }

    @Test func removesAComment() throws {
        let context = try inMemoryContext()
        let book = Book(title: "Stoner", authors: [], status: .reading)
        context.insert(book)
        let keep = try #require(book.addReadingNote(page: 1, text: "Se queda"))
        let drop = try #require(book.addReadingNote(page: 2, text: "Se va"))
        try context.save()

        book.removeReadingNote(drop)

        #expect(book.readingNotes.map(\.id) == [keep.id])
        #expect(try context.fetchCount(FetchDescriptor<ReadingNote>()) == 1)
    }

    @Test func notesSurviveStatusChanges() throws {
        let context = try inMemoryContext()
        let book = Book(title: "Stoner", authors: [], status: .reading)
        context.insert(book)
        book.addReadingNote(page: 10, text: "Guardado")

        book.status = .read
        book.status = .reading

        #expect(book.readingNotes.count == 1)
    }
}
