import CoreGraphics
import Foundation
import ImageIO
import SwiftData
import Testing
import UniformTypeIdentifiers
@testable import Booker

@MainActor
struct DominantColorExtractorTests {
    let extractor = CoreGraphicsColorExtractor()

    @Test func picksCoverColorOverWhiteMargins() async throws {
        // Portada burdeos con un margen blanco ancho, como un escaneo.
        let data = try pngData(width: 60, height: 90, background: (1, 1, 1), inset: 12, fill: (0.48, 0.18, 0.16))
        let hex = try #require(await extractor.dominantColorHex(from: data))
        let color = try #require(HexColor(hex))

        #expect(color.red > 0.4)
        #expect(color.green < 0.25)
        #expect(color.blue < 0.25)
    }

    @Test func returnsNilForInvalidData() async {
        #expect(await extractor.dominantColorHex(from: Data("no es una imagen".utf8)) == nil)
    }

    @Test func bookWithoutCoverGetsPlaceholderColor() async throws {
        let context = try inMemoryContext()
        let book = Book(title: "Stoner", authors: ["John Williams"])
        context.insert(book)

        await extractor.assignDominantColorIfNeeded(to: book)

        #expect(book.dominantColorHex == DS.CoverPalette.hex(for: "Stoner"))
    }

    @Test func dominantColorIsOnlyComputedOnce() async throws {
        let context = try inMemoryContext()
        let book = Book(title: "Stoner", authors: [], dominantColorHex: "#123456")
        context.insert(book)

        await extractor.assignDominantColorIfNeeded(to: book)

        #expect(book.dominantColorHex == "#123456")
    }

    // MARK: - Ayudas

    private func pngData(
        width: Int,
        height: Int,
        background: (Double, Double, Double),
        inset: Int,
        fill: (Double, Double, Double)
    ) throws -> Data {
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(srgbRed: background.0, green: background.1, blue: background.2, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(srgbRed: fill.0, green: fill.1, blue: fill.2, alpha: 1))
        context.fill(CGRect(x: inset, y: inset, width: width - inset * 2, height: height - inset * 2))
        let image = try #require(context.makeImage())

        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }
}

@MainActor
func inMemoryContext() throws -> ModelContext {
    let container = try ModelContainer(for: Book.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    return ModelContext(container)
}
