import SwiftUI

/// Tarjeta vertical de una recomendación: portada, título, autor y el motivo.
/// El fondo se tiñe con el color de la portada en cuanto se conoce.
struct RecommendationCard: View {
    let recommendation: Recommendation

    @Environment(\.dominantColorExtractor) private var colorExtractor
    @State private var tintHex: String?

    private var book: BookSearchResult { recommendation.book }

    var body: some View {
        VStack(spacing: DS.Spacing.l) {
            Spacer(minLength: DS.Spacing.m)

            RemoteCoverView(url: book.previewCoverURL, title: book.title, author: book.authorLine)
                .containerRelativeFrame(.horizontal) { width, _ in width * 0.42 }

            VStack(spacing: DS.Spacing.xs) {
                Text(book.title)
                    .font(DS.Typography.bookTitle)
                    .foregroundStyle(DS.Colors.inkPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)

                Text([book.authors.isEmpty ? nil : book.authorLine, book.publishedYear.map(String.init)]
                    .compactMap { $0 }
                    .joined(separator: " · "))
                    .font(DS.Typography.meta)
                    .foregroundStyle(DS.Colors.inkSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: DS.Spacing.s) {
                Text("Por qué te encaja").overlineStyle()
                Text(recommendation.reason)
                    .font(DS.Typography.reason)
                    .foregroundStyle(DS.Colors.inkPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, DS.Spacing.s)

            Spacer(minLength: DS.Spacing.m)
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.vertical, DS.Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                DS.Colors.surface
                TintGradient(colorHex: tintHex)
            }
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
        .task(id: book.previewCoverURL) {
            guard let url = book.previewCoverURL,
                  let data = await ImageDataCache.shared.imageData(for: url)
            else { return }
            tintHex = await colorExtractor.dominantColorHex(from: data)
        }
    }
}
