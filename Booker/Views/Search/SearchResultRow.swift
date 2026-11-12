import SwiftUI

/// Fila de resultado: miniatura, título en serif, autor y año.
struct SearchResultRow: View {
    let result: BookSearchResult
    let isInLibrary: Bool

    static let thumbnailWidth: CGFloat = 56
    /// 56 pt a 3x, con margen.
    static let thumbnailPixelSize = 200

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.m) {
            RemoteCoverView(url: result.thumbnailURL, title: result.title, author: result.authorLine,
                            maxPixelSize: Self.thumbnailPixelSize)
                .frame(width: Self.thumbnailWidth)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(result.title)
                    .font(DS.Typography.bookTitleCompact)
                    .foregroundStyle(DS.Colors.inkPrimary)
                    .lineLimit(2)

                if !result.authors.isEmpty {
                    Text(result.authorLine)
                        .font(DS.Typography.meta)
                        .foregroundStyle(DS.Colors.inkSecondary)
                        .lineLimit(1)
                }

                if let year = result.publishedYear {
                    Text(String(year))
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.inkTertiary)
                }

                if isInLibrary {
                    Label("En tu biblioteca", systemImage: "checkmark")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.inkSecondary)
                        .padding(.top, DS.Spacing.xxs)
                }
            }
            .padding(.top, DS.Spacing.xxs)

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(result.accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Abre las opciones para añadirlo")
    }

    private var accessibilityValue: String {
        var parts: [String] = []
        if let year = result.publishedYear { parts.append(String(year)) }
        if isInLibrary { parts.append("En tu biblioteca") }
        return parts.joined(separator: ", ")
    }
}
