import Foundation
import Testing
@testable import Booker

/// Devuelve cada vez la siguiente tanda de candidatos y recuerda qué se le excluyó.
actor ScriptedRecommender: RecommendationService {
    private var rounds: [[RecommendationCandidate]]
    private(set) var receivedExclusions: [[String]] = []
    private(set) var requestedCounts: [Int] = []

    init(rounds: [[RecommendationCandidate]]) {
        self.rounds = rounds
    }

    func candidates(for favorites: [FavoriteBook], excluding: [String], count: Int) async throws -> [RecommendationCandidate] {
        receivedExclusions.append(excluding)
        requestedCounts.append(count)
        return rounds.isEmpty ? [] : rounds.removeFirst()
    }
}

/// Un "catálogo" fijo: solo existen los libros que contiene.
struct CatalogSearch: BookSearchService {
    let books: [(title: String, author: String)]

    func search(_ query: String) async throws -> [BookSearchResult] {
        books
            .filter { query.matchKey.contains($0.title.matchKey) }
            .map { BookSearchResult(id: $0.title, source: .openLibrary, title: $0.title, authors: [$0.author]) }
    }
}

struct RecommendationEngineTests {
    let catalog = CatalogSearch(books: [
        ("Nada", "Carmen Laforet"),
        ("La invención de Morel", "Adolfo Bioy Casares"),
        ("Los recuerdos del porvenir", "Elena Garro"),
        ("Rayuela", "Julio Cortázar"),
    ])
    let favorites = [FavoriteBook(title: "Pedro Páramo", authors: ["Juan Rulfo"], rating: 5)]

    func candidate(_ title: String, _ author: String) -> RecommendationCandidate {
        RecommendationCandidate(title: title, author: author, reason: "Motivo")
    }

    @Test func discardsBooksThatDoNotExistAndAsksForMore() async throws {
        let recommender = ScriptedRecommender(rounds: [
            [candidate("El jardín de las horas quietas", "Lucía Ferrán"), candidate("Nada", "Carmen Laforet"),
             candidate("La invención de Morel", "Adolfo Bioy Casares")],
            [candidate("Rayuela", "Julio Cortázar")],
        ])
        let engine = RecommendationEngine(recommender: recommender, search: catalog)

        let result = try await engine.recommendations(for: favorites, excluding: [], count: 3)

        #expect(result.map(\.book.title) == ["Nada", "La invención de Morel", "Rayuela"])
        #expect(await recommender.requestedCounts == [3, 1])
        // La segunda ronda excluye lo ya propuesto, incluido el libro inventado.
        let secondExclusions = try #require(await recommender.receivedExclusions.last)
        #expect(secondExclusions.contains { $0.hasPrefix("El jardín de las horas quietas") })
    }

    @Test func rejectsSameTitleByAnotherAuthor() {
        let result = BookSearchResult(id: "x", source: .openLibrary, title: "Nada", authors: ["Otra Persona"])
        #expect(!RecommendationEngine.matches(candidate("Nada", "Carmen Laforet"), result))
    }

    @Test func matchesIgnoringSubtitleAndAccents() {
        let result = BookSearchResult(id: "x", source: .googleBooks, title: "Rayuela: edición conmemorativa",
                                      authors: ["Julio Cortazar"])
        #expect(RecommendationEngine.matches(candidate("Rayuela", "Julio Cortázar"), result))
    }

    @Test func stopsAfterMaxRounds() async throws {
        let fake = [candidate("No existe", "Nadie")]
        let recommender = ScriptedRecommender(rounds: [fake, fake, fake, fake])
        let engine = RecommendationEngine(recommender: recommender, search: catalog)

        let result = try await engine.recommendations(for: favorites, excluding: [], count: 3)

        #expect(result.isEmpty)
        #expect(await recommender.requestedCounts.count == 3)
    }
}

@MainActor
struct DiscoverModelTests {
    @Test func needsThreeWellRatedBooks() async throws {
        let context = try inMemoryContext()
        let books = [
            Book(title: "A", authors: ["X"], status: .read, rating: 5),
            Book(title: "B", authors: ["X"], status: .read, rating: 3.5),
            Book(title: "C", authors: ["X"], status: .reading),
        ]
        books.forEach(context.insert)
        let model = DiscoverModel()
        let engine = RecommendationEngine(recommender: ScriptedRecommender(rounds: []), search: CatalogSearch(books: []))

        await model.load(library: books, engine: engine)

        #expect(model.phase == .needsRatings(have: 1))
    }

    @Test func halfStarsCountFromFour() throws {
        let context = try inMemoryContext()
        let ratings: [Double] = [4.0, 4.5, 3.5]
        let books = ratings.map { Book(title: "Libro \($0)", authors: [], status: .read, rating: $0) }
        books.forEach(context.insert)
        #expect(DiscoverModel.favorites(in: books).map(\.rating) == [4.5, 4.0])
    }

    @Test func swipingThroughAllCardsFinishes() async throws {
        let context = try inMemoryContext()
        let books = (1...3).map { Book(title: "Favorito \($0)", authors: ["X"], status: .read, rating: 5) }
        books.forEach(context.insert)
        let recommender = ScriptedRecommender(rounds: [[
            RecommendationCandidate(title: "Nada", author: "Carmen Laforet", reason: "r"),
        ]])
        let engine = RecommendationEngine(recommender: recommender,
                                          search: CatalogSearch(books: [("Nada", "Carmen Laforet")]))
        let model = DiscoverModel()

        await model.load(library: books, engine: engine)
        #expect(model.phase == .cards)
        #expect(model.takeTopCard()?.book.title == "Nada")
        #expect(model.phase == .finished)
    }

    @Test func notConfiguredBackendIsReported() async throws {
        let context = try inMemoryContext()
        let books = (1...3).map { Book(title: "F\($0)", authors: [], status: .read, rating: 5) }
        books.forEach(context.insert)
        let engine = RecommendationEngine(recommender: UnconfiguredRecommendationService(), search: CatalogSearch(books: []))
        let model = DiscoverModel()

        await model.load(library: books, engine: engine)

        #expect(model.phase == .failed(.notConfigured))
    }
}

struct BackendRecommendationServiceTests {
    @Test func decodesWorkerResponseAndSendsJSON() async throws {
        let body = #"{"recommendations":[{"title":"Nada","author":"Carmen Laforet","reason":"Porque sí"}],"source":"mock"}"#
        let http = RecordingHTTPClient(status: 200, body: Data(body.utf8))
        let service = BackendRecommendationService(baseURL: URL(string: "http://localhost:8787")!, http: http)

        let result = try await service.candidates(
            for: [FavoriteBook(title: "Pedro Páramo", authors: ["Juan Rulfo"], rating: 5)], excluding: ["Rayuela"], count: 3
        )

        #expect(result == [RecommendationCandidate(title: "Nada", author: "Carmen Laforet", reason: "Porque sí")])
        let request = try #require(await http.lastRequest)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/recommendations")
        let sent = try JSONSerialization.jsonObject(with: try #require(request.httpBody)) as? [String: Any]
        #expect(sent?["count"] as? Int == 3)
    }

    @Test func serviceUnavailableMeansNotConfigured() async {
        let http = RecordingHTTPClient(status: 503, body: Data())
        let service = BackendRecommendationService(baseURL: URL(string: "http://localhost:8787")!, http: http)
        await #expect(throws: RecommendationError.notConfigured) {
            try await service.candidates(for: [], excluding: [], count: 3)
        }
    }

    @Test func backendClientAddsToken() async throws {
        let base = RecordingHTTPClient(status: 200, body: Data())
        let client = BackendHTTPClient(base: base, token: "secreto")
        _ = try await client.get(URL(string: "http://localhost:8787/health")!)
        #expect(await base.lastRequest?.value(forHTTPHeaderField: "X-Booker-Token") == "secreto")
    }
}

actor RecordingHTTPClient: HTTPClient {
    let status: Int
    let body: Data
    private(set) var lastRequest: URLRequest?

    init(status: Int, body: Data) {
        self.status = status
        self.body = body
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lastRequest = request
        return (body, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}
