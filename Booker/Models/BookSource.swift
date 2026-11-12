import Foundation

/// Cómo llegó un libro a la biblioteca.
enum BookSource: String, Codable, CaseIterable, Sendable {
    case manual
    case recommendation
}
