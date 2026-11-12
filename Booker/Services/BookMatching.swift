import Foundation

/// ¿Es este resultado el libro que buscamos? Lo usan Descubrir (para verificar
/// recomendaciones) y la búsqueda de portadas en Apple Books.
enum BookMatching {
    /// Mismo título (ignorando subtítulo, tildes y puntuación, y admitiendo que
    /// uno empiece por el otro) y el apellido del autor entre los autores.
    static func matches(title: String, author: String?, candidateTitle: String, candidateAuthors: [String]) -> Bool {
        let wanted = title.titleKey
        let found = candidateTitle.titleKey
        guard !wanted.isEmpty, !found.isEmpty,
              wanted == found || found.hasPrefix(wanted) || wanted.hasPrefix(found)
        else { return false }

        guard let surname = author?.matchKey.split(separator: " ").last.map(String.init), !surname.isEmpty else {
            return true
        }
        return candidateAuthors.contains { $0.matchKey.contains(surname) }
    }

    /// Título idéntico, no solo uno que empieza igual ("…: adaptación gráfica").
    static func isExactTitle(_ title: String, _ candidateTitle: String) -> Bool {
        title.titleKey == candidateTitle.titleKey
    }
}

extension String {
    /// Título comparable: sin subtítulo, tildes, mayúsculas ni puntuación.
    var titleKey: String {
        let main = split(separator: ":", maxSplits: 1).first.map(String.init) ?? self
        return main.matchKey
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) || $0 == " " }
            .map(String.init)
            .joined()
            .split(separator: " ")
            .joined(separator: " ")
    }
}
