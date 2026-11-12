import SwiftUI

// Servicios inyectados por el entorno, para poder sustituirlos por mocks
// en previews y tests.

private struct DominantColorExtractorKey: EnvironmentKey {
    static let defaultValue: any DominantColorExtracting = CoreGraphicsColorExtractor()
}

private struct BookSearchServiceKey: EnvironmentKey {
    static let defaultValue: any BookSearchService = AppConfiguration.makeBookSearchService()
}

private struct CoverImageProviderKey: EnvironmentKey {
    static let defaultValue: any CoverImageProviding = CoverImageService()
}

private struct RecommendationServiceKey: EnvironmentKey {
    static let defaultValue: any RecommendationService = AppConfiguration.makeRecommendationService()
}

extension EnvironmentValues {
    var recommendationService: any RecommendationService {
        get { self[RecommendationServiceKey.self] }
        set { self[RecommendationServiceKey.self] = newValue }
    }

    var dominantColorExtractor: any DominantColorExtracting {
        get { self[DominantColorExtractorKey.self] }
        set { self[DominantColorExtractorKey.self] = newValue }
    }

    var bookSearchService: any BookSearchService {
        get { self[BookSearchServiceKey.self] }
        set { self[BookSearchServiceKey.self] = newValue }
    }

    var coverImageProvider: any CoverImageProviding {
        get { self[CoverImageProviderKey.self] }
        set { self[CoverImageProviderKey.self] = newValue }
    }
}
