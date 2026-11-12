import SwiftData
import SwiftUI

/// Pantalla principal: cuadrícula de portadas en dos columnas, filtrable por estado.
struct LibraryView: View {
    @Query(sort: \Book.dateAdded, order: .reverse) private var books: [Book]
    @State private var filter: LibraryFilter = .all

    private let columns = [
        GridItem(.flexible(), spacing: DS.Layout.gridColumnSpacing),
        GridItem(.flexible(), spacing: DS.Layout.gridColumnSpacing),
    ]

    /// Se filtra en memoria (y no con un `#Predicate`) para que la cuadrícula
    /// pueda animar la entrada y salida de portadas al cambiar de filtro.
    private var visibleBooks: [Book] {
        books.filter(filter.includes)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    header
                    StatusFilterBar(selection: $filter)

                    if visibleBooks.isEmpty {
                        LibraryEmptyState(filter: filter)
                            .transition(.opacity)
                    } else {
                        grid
                    }
                }
                .padding(.horizontal, DS.Spacing.gutter)
                .padding(.top, DS.Spacing.l)
                .padding(.bottom, DS.Spacing.xxxl)
            }
            .scrollIndicators(.hidden)
            .background(DS.Colors.canvas.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("Registro de lectura")
                .overlineStyle()

            Text("Biblioteca")
                .font(DS.Typography.display)
                .foregroundStyle(DS.Colors.inkPrimary)
                .accessibilityAddTraits(.isHeader)

            Text(summary)
                .font(DS.Typography.meta)
                .foregroundStyle(DS.Colors.inkSecondary)
                .contentTransition(.numericText())
        }
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: DS.Layout.gridRowSpacing) {
            ForEach(visibleBooks) { book in
                BookCoverView(book: book)
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
            }
        }
    }

    private var summary: String {
        let total = books.count
        let reading = books.filter { $0.status == .reading }.count
        let totalText = total == 1 ? "1 libro" : "\(total) libros"
        return reading > 0 ? "\(totalText) · \(reading) en curso" : totalText
    }
}

#Preview("Biblioteca") {
    LibraryView()
        .modelContainer(SampleData.previewContainer)
}

#Preview("Biblioteca · Oscuro") {
    LibraryView()
        .modelContainer(SampleData.previewContainer)
        .preferredColorScheme(.dark)
}

#Preview("Biblioteca · Vacía") {
    LibraryView()
        .modelContainer(for: Book.self, inMemory: true)
}
