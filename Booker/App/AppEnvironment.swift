import SwiftUI

// Servicios inyectados por el entorno, para poder sustituirlos por mocks
// en previews y tests.

private struct DominantColorExtractorKey: EnvironmentKey {
    static let defaultValue: any DominantColorExtracting = CoreGraphicsColorExtractor()
}

extension EnvironmentValues {
    var dominantColorExtractor: any DominantColorExtracting {
        get { self[DominantColorExtractorKey.self] }
        set { self[DominantColorExtractorKey.self] = newValue }
    }
}
