import Foundation
import Testing
@testable import Booker

@MainActor
struct BookTests {
    @Test func ratingUsesHalfStepsBetweenHalfAndFive() throws {
        let context = try inMemoryContext()
        let book = Book(title: "Ficciones", authors: ["Jorge Luis Borges"], status: .read)
        context.insert(book)

        book.setRating(3.5)
        #expect(book.rating == 3.5)
        book.setRating(3.7)
        #expect(book.rating == 3.5)
        book.setRating(3.8)
        #expect(book.rating == 4)
        book.setRating(9)
        #expect(book.rating == 5)
        book.setRating(0)
        #expect(book.rating == 0.5)
        book.setRating(nil)
        #expect(book.rating == nil)
    }

    @Test func ratingIsIgnoredUnlessRead() throws {
        let context = try inMemoryContext()
        let book = Book(title: "Middlemarch", authors: ["George Eliot"], status: .toRead, rating: 4)
        context.insert(book)

        #expect(book.rating == nil)
        book.setRating(3)
        #expect(book.rating == nil)
    }

    @Test func leavingReadClearsRatingAndFinishDate() throws {
        let context = try inMemoryContext()
        let book = Book(title: "Pedro Páramo", authors: ["Juan Rulfo"], status: .read, rating: 5)
        context.insert(book)
        #expect(book.dateFinished != nil)

        book.status = .reading

        #expect(book.rating == nil)
        #expect(book.dateFinished == nil)
    }

    @Test func markingAsReadSetsFinishDate() throws {
        let context = try inMemoryContext()
        let book = Book(title: "Stoner", authors: ["John Williams"], status: .reading)
        context.insert(book)

        book.status = .read

        #expect(book.dateFinished != nil)
    }

    @Test func hexColorParsing() throws {
        let color = try #require(HexColor("#FF8000"))
        #expect(color.red == 1)
        #expect(abs(color.green - 128.0 / 255) < 0.001)
        #expect(color.blue == 0)
        #expect(HexColor("nope") == nil)
    }
}
