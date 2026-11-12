import Foundation
import Observation

/// Estado del buscador. La vista llama a `search(using:)` cada vez que
/// cambia el texto (con `.task(id:)`, que cancela la búsqueda anterior);
/// la espera inicial hace de debounce.
@Observable
@MainActor
final class SearchModel {
    enum Phase: Equatable {
        case idle
        case results([BookSearchResult])
        case noResults(query: String)
        case failed(isOffline: Bool)
    }

    var query = ""
    private(set) var phase: Phase = .idle
    private(set) var isLoading = false
    private var lastSearchedQuery: String?

    static let minimumQueryLength = 2

    var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func search(using service: any BookSearchService, debounce: Duration = .milliseconds(350)) async {
        let query = trimmedQuery
        guard query.count >= Self.minimumQueryLength else {
            phase = .idle
            isLoading = false
            lastSearchedQuery = nil
            return
        }
        // Por ejemplo, al volver a esta pestaña con el mismo texto.
        if query == lastSearchedQuery, !isFailed { return }

        do {
            try await Task.sleep(for: debounce)
            isLoading = true
            let results = try await service.search(query)
            lastSearchedQuery = query
            phase = results.isEmpty ? .noResults(query: query) : .results(results)
            isLoading = false
        } catch is CancellationError {
            // Llegó otra búsqueda; ella se encarga de `isLoading`.
        } catch {
            phase = .failed(isOffline: (error as? BookSearchError) == .offline)
            isLoading = false
        }
    }

    func retry(using service: any BookSearchService) async {
        lastSearchedQuery = nil
        await search(using: service, debounce: .zero)
    }

    private var isFailed: Bool {
        if case .failed = phase { true } else { false }
    }
}
