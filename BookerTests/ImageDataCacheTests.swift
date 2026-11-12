import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Booker

/// Cuenta las peticiones que llegan a la red.
actor RequestCounter {
    private(set) var count = 0
    func increment() { count += 1 }
}

struct CountingHTTPClient: HTTPClient {
    let counter = RequestCounter()
    var status = 200
    var body: Data
    var delay: Duration = .zero

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let url = request.url!
        await counter.increment()
        try await Task.sleep(for: delay)
        return (body, HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}

struct ImageDataCacheTests {
    let url = URL(string: "https://covers.example/1-L.jpg")!

    @Test func secondRequestIsServedFromMemory() async throws {
        let http = CountingHTTPClient(body: try samplePNG())
        let cache = ImageDataCache(http: http, directory: nil)

        #expect(await cache.imageData(for: url) != nil)
        #expect(await cache.imageData(for: url) != nil)
        #expect(await http.counter.count == 1)
    }

    @Test func concurrentRequestsShareOneDownload() async throws {
        let http = CountingHTTPClient(body: try samplePNG(), delay: .milliseconds(100))
        let cache = ImageDataCache(http: http, directory: nil)

        async let first = cache.imageData(for: url)
        async let second = cache.imageData(for: url)
        let results = await [first, second]

        #expect(results.allSatisfy { $0 != nil })
        #expect(await http.counter.count == 1)
    }

    @Test func diskCacheSurvivesANewInstance() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }

        let online = ImageDataCache(http: CountingHTTPClient(body: try samplePNG()), directory: directory)
        #expect(await online.imageData(for: url) != nil)

        let offline = CountingHTTPClient(status: 500, body: Data())
        let relaunched = ImageDataCache(http: offline, directory: directory)
        #expect(await relaunched.imageData(for: url) != nil)
        #expect(await offline.counter.count == 0)
    }

    @Test func missingImagesAreNotRequestedTwice() async throws {
        let http = CountingHTTPClient(status: 404, body: Data())
        let cache = ImageDataCache(http: http, directory: nil)

        #expect(await cache.imageData(for: url) == nil)
        #expect(await cache.imageData(for: url) == nil)
        #expect(await http.counter.count == 1)
    }

    private func samplePNG() throws -> Data {
        let context = try #require(CGContext(
            data: nil, width: 30, height: 45, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(srgbRed: 0.5, green: 0.2, blue: 0.2, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 30, height: 45))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }
}
