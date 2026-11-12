import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Booker

// MARK: - Mock de red

/// Responde a cada URL con lo que se le haya dado, o 404.
struct MockHTTPClient: HTTPClient {
    var responses: [URL: (Int, Data)] = [:]
    var error: URLError?

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let url = request.url!
        if let error { throw error }
        let (status, data) = responses[url] ?? (404, Data())
        return (data, HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}

func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle(for: FixtureBundleToken.self).url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

private final class FixtureBundleToken {}

// MARK: - Open Library

struct OpenLibrarySearchTests {
    @Test func decodesRealResponse() async throws {
        var service = OpenLibrarySearchService()
        let url = service.searchURL(for: "stoner john williams")
        service.http = MockHTTPClient(responses: [url: (200, try fixture("openlibrary-search"))])

        let results = try await service.search("stoner john williams")

        let first = try #require(results.first)
        #expect(results.count == 3)
        #expect(first.title == "Stoner")
        #expect(first.authors == ["John Williams"])
        #expect(first.publishedYear == 1965)
        #expect(first.isbn?.count == 13)
        #expect(first.thumbnailURL?.absoluteString == "https://covers.openlibrary.org/b/id/8310729-M.jpg")
        #expect(first.openLibraryCoverURLs.first?.absoluteString == "https://covers.openlibrary.org/b/id/8310729-L.jpg")
    }

    @Test func isbnQueriesUseTheIsbnField() throws {
        let url = OpenLibrarySearchService().searchURL(for: "978-1-59017-199-8")
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(items.first { $0.name == "q" }?.value == "isbn:9781590171998")
    }

    @Test func offlineErrorIsReported() async {
        let service = OpenLibrarySearchService(http: MockHTTPClient(error: URLError(.notConnectedToInternet)))
        await #expect(throws: BookSearchError.offline) {
            try await service.search("stoner")
        }
    }

    @Test func serverErrorIsReported() async {
        let service = OpenLibrarySearchService(http: MockHTTPClient())
        await #expect(throws: BookSearchError.server(statusCode: 404)) {
            try await service.search("stoner")
        }
    }
}

// MARK: - Google Books

struct GoogleBooksSearchTests {
    @Test func decodesVolumesAndSecuresCoverURL() async throws {
        var service = GoogleBooksSearchService(baseURL: URL(string: "https://backend.example/books/v1")!)
        let url = service.searchURL(for: "stoner")
        service.http = MockHTTPClient(responses: [url: (200, try fixture("googlebooks-search"))])

        let results = try await service.search("stoner")

        #expect(results.count == 2)
        let first = try #require(results.first)
        #expect(first.googleBooksID == "abc123XYZ")
        #expect(first.isbn == "9788415130307")
        #expect(first.publishedYear == 2010)
        let cover = try #require(first.googleCoverURL?.absoluteString)
        #expect(cover.hasPrefix("https://"))
        #expect(!cover.contains("edge=curl"))
        #expect(first.openLibraryCoverURLs.first?.absoluteString.contains("9788415130307") == true)

        #expect(results[1].thumbnailURL == nil)
        #expect(results[1].publishedYear == 1965)
    }

    @Test func fallsBackToOpenLibraryWhenGoogleFails() async throws {
        let failingGoogle = GoogleBooksSearchService(baseURL: URL(string: "https://backend.example/books/v1")!, http: MockHTTPClient())
        var openLibrary = OpenLibrarySearchService()
        openLibrary.http = MockHTTPClient(responses: [openLibrary.searchURL(for: "stoner"): (200, try fixture("openlibrary-search"))])

        let results = try await FallbackBookSearchService(primary: failingGoogle, fallback: openLibrary).search("stoner")

        #expect(results.first?.source == .openLibrary)
    }
}

// MARK: - Portadas

struct CoverImageServiceTests {
    let googleURL = URL(string: "https://books.google.com/cover")!
    let openLibraryURL = URL(string: "https://covers.openlibrary.org/b/id/1-L.jpg")!

    var result: BookSearchResult {
        BookSearchResult(id: "x", source: .googleBooks, title: "Stoner", authors: [],
                         googleCoverURL: googleURL, openLibraryCoverURLs: [openLibraryURL])
    }

    @Test func keepsGoogleCoverWhenItIsLargeEnough() async throws {
        let http = MockHTTPClient(responses: [
            googleURL: (200, try png(width: 400, height: 600)),
            openLibraryURL: (200, try png(width: 300, height: 500)),
        ])
        let cover = await CoverImageService(images: ImageDataCache(http: http, directory: nil)).bestCover(for: result)
        #expect(cover?.url == googleURL)
    }

    @Test func usesOpenLibraryWhenGoogleCoverIsLowResolution() async throws {
        let http = MockHTTPClient(responses: [
            googleURL: (200, try png(width: 128, height: 190)),
            openLibraryURL: (200, try png(width: 300, height: 500)),
        ])
        let cover = await CoverImageService(images: ImageDataCache(http: http, directory: nil)).bestCover(for: result)
        #expect(cover?.url == openLibraryURL)
        #expect(cover?.pixelHeight == 500)
    }

    @Test func keepsLowResolutionGoogleCoverIfThereIsNothingBetter() async throws {
        let http = MockHTTPClient(responses: [googleURL: (200, try png(width: 128, height: 190))])
        let cover = await CoverImageService(images: ImageDataCache(http: http, directory: nil)).bestCover(for: result)
        #expect(cover?.url == googleURL)
    }

    @Test func ignoresOnePixelPlaceholders() async throws {
        let http = MockHTTPClient(responses: [openLibraryURL: (200, try png(width: 1, height: 1))])
        let cover = await CoverImageService(images: ImageDataCache(http: http, directory: nil)).bestCover(for: result)
        #expect(cover == nil)
    }

    private func png(width: Int, height: Int) throws -> Data {
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(srgbRed: 0.2, green: 0.3, blue: 0.4, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }
}

// MARK: - Buscador y biblioteca

@MainActor
struct SearchModelTests {
    struct StubService: BookSearchService {
        var results: [BookSearchResult] = []
        var error: BookSearchError?
        func search(_ query: String) async throws -> [BookSearchResult] {
            if let error { throw error }
            return results
        }
    }

    @Test func shortQueriesStayIdle() async {
        let model = SearchModel()
        model.query = "a"
        await model.search(using: StubService(), debounce: .zero)
        #expect(model.phase == .idle)
    }

    @Test func emptyResultsShowNoResults() async {
        let model = SearchModel()
        model.query = "  xqzz  "
        await model.search(using: StubService(), debounce: .zero)
        #expect(model.phase == .noResults(query: "xqzz"))
    }

    @Test func offlineShowsOfflineError() async {
        let model = SearchModel()
        model.query = "stoner"
        await model.search(using: StubService(error: .offline), debounce: .zero)
        #expect(model.phase == .failed(isOffline: true))
        #expect(!model.isLoading)
    }

    @Test func detectsBooksAlreadyInLibraryIgnoringAccents() throws {
        let context = try inMemoryContext()
        let book = Book(title: "Cien años de soledad", authors: ["Gabriel García Márquez"])
        context.insert(book)
        let result = BookSearchResult(id: "x", source: .openLibrary, title: "CIEN AÑOS DE SOLEDAD",
                                      authors: ["Gabriel Garcia Marquez"])
        #expect(result.isInLibrary([book]))
    }
}
