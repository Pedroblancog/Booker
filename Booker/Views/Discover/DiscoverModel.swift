import Foundation
import Observation

/// Estado de Descubrir: decide si hay suficientes favoritos, pide las
/// recomendaciones verificadas y lleva la pila de tarjetas.
@Observable
@MainActor
final class DiscoverModel {
    enum Phase: Equatable {
        case idle
        case needsRatings(have: Int)
        case loading
        case cards
        case finished
        case failed(RecommendationError)
    }

    static let minimumFavorites = 3
    static let favoriteRating = 4.0
    static let cardsPerRound = 3

    private(set) var phase: Phase = .idle
    /// La primera es la que está arriba de la pila.
    private(set) var cards: [Recommendation] = []
    /// Lo ya mostrado en esta sesión (guardado o descartado), para no repetirlo.
    private var seen: [String] = []

    /// Libros leídos con 4 estrellas o más, los mejor puntuados primero.
    static func favorites(in library: [Book]) -> [FavoriteBook] {
        library
            .filter { $0.status == .read && ($0.rating ?? 0) >= favoriteRating }
            .sorted { ($0.rating ?? 0, $0.dateFinished ?? .distantPast) > ($1.rating ?? 0, $1.dateFinished ?? .distantPast) }
            .prefix(20)
            .map { FavoriteBook(title: $0.title, authors: $0.authors, rating: $0.rating ?? 0) }
    }

    /// Se llama al aparecer y cuando cambia el número de favoritos: solo
    /// carga si aún no hay tarjetas que enseñar.
    func refreshIfNeeded(library: [Book], engine: RecommendationEngine) async {
        switch phase {
        case .idle, .needsRatings: await load(library: library, engine: engine)
        default: break
        }
    }

    func load(library: [Book], engine: RecommendationEngine) async {
        let favorites = Self.favorites(in: library)
        guard favorites.count >= Self.minimumFavorites else {
            phase = .needsRatings(have: favorites.count)
            return
        }

        phase = .loading
        let exclude = library.map { "\($0.title) — \($0.authorLine)" } + seen
        do {
            let recommendations = try await engine.recommendations(
                for: favorites, excluding: exclude, count: Self.cardsPerRound
            )
            cards = recommendations
            phase = recommendations.isEmpty ? .failed(.unavailable) : .cards
        } catch is CancellationError {
            phase = .idle
        } catch let error as RecommendationError {
            phase = .failed(error)
        } catch {
            phase = .failed(.unavailable)
        }
    }

    /// Quita la tarjeta de arriba y la devuelve (para guardarla, si procede).
    @discardableResult
    func takeTopCard() -> Recommendation? {
        guard !cards.isEmpty else { return nil }
        let card = cards.removeFirst()
        seen.append("\(card.book.title) — \(card.book.authorLine)")
        if cards.isEmpty { phase = .finished }
        return card
    }
}
