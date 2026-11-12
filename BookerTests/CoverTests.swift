import Foundation
import SwiftData
import Testing
@testable import Booker

// MARK: - Apple Books

struct AppleBooksCoverLookupTests {
    @Test func findsTheHighResolutionCoverInTheFixture() async throws {
        var lookup = AppleBooksCoverLookup(storefronts: ["es"], memo: nil)
        let url = lookup.searchURL(title: "Pedro Páramo", author: "Juan Rulfo", country: "es")
        lookup.http = MockHTTPClient(responses: [url: (200, try fixture("applebooks-search"))])

        let cover = try #require(await lookup.coverURL(title: "Pedro Páramo", author: "Juan Rulfo"))

        #expect(cover.absoluteString == "https://is1-ssl.mzstatic.com/image/thumb/Publication221/v4/ec/c8/99/ecc89957-1cc3-6a8a-eb1a-a99ad2d96223/1028742243.jpg/1600x1600bb.jpg")
    }

    @Test func searchesEbooksInTheGivenStore() throws {
        let url = AppleBooksCoverLookup().searchURL(title: "Stoner: novela", author: "John Williams", country: "es")
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(items.contains(URLQueryItem(name: "term", value: "Stoner John Williams")))
        #expect(items.contains(URLQueryItem(name: "media", value: "ebook")))
        #expect(items.contains(URLQueryItem(name: "country", value: "es")))
    }

    @Test func triesTheNextStoreWhenNothingMatches() async throws {
        var lookup = AppleBooksCoverLookup(storefronts: ["mx", "es"], memo: nil)
        let mexico = lookup.searchURL(title: "Pedro Páramo", author: "Juan Rulfo", country: "mx")
        let spain = lookup.searchURL(title: "Pedro Páramo", author: "Juan Rulfo", country: "es")
        lookup.http = MockHTTPClient(responses: [
            mexico: (200, Data(#"{"resultCount":0,"results":[]}"#.utf8)),
            spain: (200, try fixture("applebooks-search")),
        ])
        #expect(await lookup.coverURL(title: "Pedro Páramo", author: "Juan Rulfo") != nil)
    }

    @Test func rejectsOtherBooksAndAuthors() {
        let items: [AppleBooksCoverLookup.SearchResponse.Item] = [
            .init(trackName: "Guía de lectura de Pedro Páramo", artistName: "Juan Rulfo", artworkUrl100: "https://a.example/x.jpg/100x100bb.jpg"),
            .init(trackName: "Pedro Páramo", artistName: "Otro Autor", artworkUrl100: "https://a.example/y.jpg/100x100bb.jpg"),
        ]
        #expect(AppleBooksCoverLookup.bestArtwork(in: items, title: "Pedro Páramo", author: "Juan Rulfo", size: 1600) == nil)
    }

    @Test func prefersTheExactTitle() {
        let items: [AppleBooksCoverLookup.SearchResponse.Item] = [
            .init(trackName: "Ficciones (edición conmemorativa)", artistName: "Jorge Luis Borges", artworkUrl100: "https://a.example/a.jpg/100x100bb.jpg"),
            .init(trackName: "Ficciones", artistName: "Jorge Luis Borges", artworkUrl100: "https://a.example/b.jpg/100x100bb.jpg"),
        ]
        let url = AppleBooksCoverLookup.bestArtwork(in: items, title: "Ficciones", author: "Jorge Luis Borges", size: 1600)
        #expect(url?.absoluteString == "https://a.example/b.jpg/1600x1600bb.jpg")
    }

    @Test func withoutAuthorOnlyTheExactTitleCounts() {
        let items: [AppleBooksCoverLookup.SearchResponse.Item] = [
            .init(trackName: "Stoner: guía de lectura", artistName: "Resúmenes Express", artworkUrl100: "https://a.example/a.jpg/100x100bb.jpg"),
        ]
        #expect(AppleBooksCoverLookup.bestArtwork(in: items, title: "Stoner (novela)", author: nil, size: 1600) == nil)
    }

    @Test func remembersEarlierLookups() async throws {
        var lookup = AppleBooksCoverLookup(storefronts: ["es"], memo: LookupMemo())
        let url = lookup.searchURL(title: "Pedro Páramo", author: "Juan Rulfo", country: "es")
        lookup.http = MockHTTPClient(responses: [url: (200, try fixture("applebooks-search"))])
        let first = await lookup.coverURL(title: "Pedro Páramo", author: "Juan Rulfo")

        lookup.http = MockHTTPClient()
        #expect(await lookup.coverURL(title: "Pedro Páramo", author: "Juan Rulfo") == first)
    }
}

// MARK: - Mejora de portadas guardadas

@MainActor
struct CoverUpgraderTests {
    struct StubCovers: CoverImageProviding {
        let cover: CoverImage?
        func bestCover(title: String, authors: [String], candidates: [URL]) async -> CoverImage? { cover }
    }

    struct FixedColor: DominantColorExtracting {
        func dominantColorHex(from imageData: Data) async -> String? { "#123456" }
    }

    func upgrader(_ context: ModelContext, cover: CoverImage?, defaults: UserDefaults) -> CoverUpgrader {
        CoverUpgrader(context: context, covers: StubCovers(cover: cover), colors: FixedColor(), defaults: defaults, pause: .zero)
    }

    func freshDefaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "test-\(UUID().uuidString)"))
    }

    @Test func replacesASmallCoverWithASharperOne() async throws {
        let context = try inMemoryContext()
        let book = Book(title: "Stoner", authors: ["John Williams"], coverImageData: try pngData(width: 300, height: 500))
        book.dominantColorHex = "#FFFFFF"
        context.insert(book)
        let sharp = CoverImage(data: try pngData(width: 1000, height: 1600), url: URL(string: "https://a.example/c.jpg")!,
                               pixelWidth: 1000, pixelHeight: 1600)

        await upgrader(context, cover: sharp, defaults: try freshDefaults()).upgradeLibrary()

        #expect(book.coverURL == sharp.url)
        #expect(book.coverImageData == sharp.data)
        #expect(book.dominantColorHex == "#123456")
    }

    @Test func keepsTheCoverWhenNothingIsBetter() async throws {
        let context = try inMemoryContext()
        let original = try pngData(width: 300, height: 500)
        let book = Book(title: "Stoner", authors: [], coverImageData: original)
        context.insert(book)
        let worse = CoverImage(data: try pngData(width: 128, height: 190), url: URL(string: "https://a.example/s.jpg")!,
                               pixelWidth: 128, pixelHeight: 190)

        #expect(await upgrader(context, cover: worse, defaults: try freshDefaults()).upgrade(book) == false)
        #expect(book.coverImageData == original)
    }

    @Test func triesEachBookOnlyOnce() async throws {
        let context = try inMemoryContext()
        let book = Book(title: "Stoner", authors: [])
        context.insert(book)
        let defaults = try freshDefaults()

        await upgrader(context, cover: nil, defaults: defaults).upgradeLibrary()
        let sharp = CoverImage(data: try pngData(width: 1000, height: 1600), url: URL(string: "https://a.example/c.jpg")!,
                               pixelWidth: 1000, pixelHeight: 1600)
        await upgrader(context, cover: sharp, defaults: defaults).upgradeLibrary()

        #expect(book.coverImageData == nil)
    }

    @Test func skipsCoversThatAreAlreadySharp() throws {
        let context = try inMemoryContext()
        let book = Book(title: "Stoner", authors: [], coverImageData: try pngData(width: 1000, height: 1600))
        context.insert(book)
        #expect(upgrader(context, cover: nil, defaults: try freshDefaults()).needsUpgrade(book) == false)
    }

    @Test func asksGoogleForTheLargeVersionOfItsCover() throws {
        let context = try inMemoryContext()
        let book = Book(isbn: "9788415130307", title: "Stoner", authors: [],
                        coverURL: URL(string: "https://books.google.com/books/content?id=abc&printsec=frontcover&img=1&zoom=1&source=gbs_api"))
        context.insert(book)
        let urls = upgrader(context, cover: nil, defaults: try freshDefaults()).candidates(for: book).map(\.absoluteString)
        #expect(urls.first?.contains("fife=w1000-h1500") == true)
        #expect(urls.last == "https://covers.openlibrary.org/b/isbn/9788415130307-L.jpg?default=false")
    }
}

// MARK: - Proporción

struct CoverAspectTests {
    @Test func usesTheRealProportionWithinLimits() {
        #expect(abs(CoverArtwork.aspectRatio(width: 1000, height: 1600) - 0.625) < 0.001)
        #expect(CoverArtwork.aspectRatio(width: 1000, height: 1000) == DS.Layout.coverAspectRange.upperBound)
        #expect(CoverArtwork.aspectRatio(width: 100, height: 1000) == DS.Layout.coverAspectRange.lowerBound)
        #expect(CoverArtwork.aspectRatio(width: 0, height: 0) == DS.Layout.coverAspectRatio)
    }
}
