import Foundation

/// Una recomendación verificada: el libro existe y tenemos sus datos reales.
struct Recommendation: Identifiable, Equatable, Sendable {
    let book: BookSearchResult
    let reason: String

    var id: String { book.id }
}

/// Pide candidatos al recomendador y comprueba cada uno contra la búsqueda
/// de libros (Google Books a través del backend, u Open Library). Los que no
/// existen se descartan y se piden otros, hasta `maxRounds` rondas.
struct RecommendationEngine: Sendable {
    let recommender: any RecommendationService
    let search: any BookSearchService
    var maxRounds = 3

    func recommendations(for favorites: [FavoriteBook], excluding: [String], count: Int) async throws -> [Recommendation] {
        var verified: [Recommendation] = []
        var exclude = excluding

        for _ in 0..<maxRounds {
            let missing = count - verified.count
            guard missing > 0 else { break }

            let candidates = try await recommender.candidates(for: favorites, excluding: exclude, count: missing)
            guard !candidates.isEmpty else { break }
            // Ni estos ni sus sustitutos deben volver a aparecer.
            exclude += candidates.map { "\($0.title) — \($0.author)" }

            let outcomes = await verifyAll(candidates)
            if outcomes.allSatisfy({ $0 == .searchFailed }) { throw RecommendationError.unavailable }

            for case .found(let recommendation) in outcomes
            where !verified.contains(where: { $0.book.title.titleKey == recommendation.book.title.titleKey }) {
                verified.append(recommendation)
            }
        }
        return Array(verified.prefix(count))
    }

    enum Outcome: Equatable {
        case found(Recommendation)
        case notFound
        case searchFailed
    }

    /// Verifica en paralelo, conservando el orden en que llegaron.
    private func verifyAll(_ candidates: [RecommendationCandidate]) async -> [Outcome] {
        await withTaskGroup(of: (Int, Outcome).self) { group in
            for (index, candidate) in candidates.enumerated() {
                group.addTask { (index, await verify(candidate)) }
            }
            var outcomes = [Outcome](repeating: .notFound, count: candidates.count)
            for await (index, outcome) in group { outcomes[index] = outcome }
            return outcomes
        }
    }

    func verify(_ candidate: RecommendationCandidate) async -> Outcome {
        let results: [BookSearchResult]
        do {
            results = try await search.search("\(candidate.title) \(candidate.author)")
        } catch {
            return .searchFailed
        }
        let matches = results.prefix(10).filter { Self.matches(candidate, $0) }
        guard let match = matches.min(by: { Self.isPreferredEdition($0, $1, of: candidate) }) else { return .notFound }
        return .found(Recommendation(book: match, reason: candidate.reason))
    }

    /// Entre ediciones del mismo libro, por orden: con portada; con el título
    /// exacto (no un volumen doble que solo empieza igual); sin subtítulo
    /// (descarta guías de estudio que comparten título); y la más antigua
    /// (las reediciones recientes darían un año engañoso).
    static func isPreferredEdition(_ a: BookSearchResult, _ b: BookSearchResult, of candidate: RecommendationCandidate) -> Bool {
        let wanted = candidate.title.titleKey
        func rank(_ book: BookSearchResult) -> (Int, Int, Int, Int) {
            (book.thumbnailURL == nil ? 1 : 0,
             book.title.titleKey == wanted ? 0 : 1,
             (book.subtitle?.isEmpty ?? true) ? 0 : 1,
             book.publishedYear ?? .max)
        }
        return rank(a) < rank(b)
    }

    static func matches(_ candidate: RecommendationCandidate, _ result: BookSearchResult) -> Bool {
        BookMatching.matches(title: candidate.title, author: candidate.author,
                             candidateTitle: result.title, candidateAuthors: result.authors)
    }
}
