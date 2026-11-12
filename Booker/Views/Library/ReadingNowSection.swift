import SwiftUI

/// "Leyendo ahora": los libros en curso en grande, como la portada de una
/// revista. Con varios, se pasan de lado y cada uno se ajusta al centro.
struct ReadingNowSection: View {
    let books: [Book]
    let transitionNamespace: Namespace.ID

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            Text("Leyendo ahora")
                .overlineStyle()
                .accessibilityAddTraits(.isHeader)

            if books.count == 1, let book = books.first {
                item(book)
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: DS.Spacing.l) {
                        ForEach(books) { book in
                            item(book)
                                .containerRelativeFrame(.horizontal) { width, _ in width * 0.86 }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
            }
        }
    }

    private func item(_ book: Book) -> some View {
        NavigationLink(value: BookRoute(book: book, source: .readingNow)) {
            HStack(alignment: .top, spacing: DS.Spacing.m) {
                BookCoverView(book: book)
                    .frame(width: 104)
                    .zoomTransitionSource(id: BookRoute.transitionID(book, .readingNow), in: transitionNamespace)

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(book.title)
                        .font(DS.Typography.bookTitle)
                        .foregroundStyle(DS.Colors.inkPrimary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    if !book.authors.isEmpty {
                        Text(book.authorLine)
                            .font(DS.Typography.meta)
                            .foregroundStyle(DS.Colors.inkSecondary)
                            .lineLimit(2)
                    }

                    Text("En tu mesa desde el \(book.dateAdded.formatted(.dateTime.day().month(.wide)))")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.inkTertiary)
                        .padding(.top, DS.Spacing.xxs)

                    Spacer(minLength: DS.Spacing.s)

                    HStack(spacing: DS.Spacing.xxs) {
                        Text("Seguir")
                        Image(systemName: "arrow.right")
                    }
                    .font(DS.Typography.menuSelected)
                    .foregroundStyle(DS.Colors.accent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Leyendo ahora: \(book.accessibilityLabel)")
        .accessibilityHint("Abre el detalle")
    }
}
