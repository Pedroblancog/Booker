import SwiftData
import SwiftUI

/// Pantalla principal: cuadrícula de portadas en tres columnas, filtrable por estado.
struct LibraryView: View {
    /// Animado: un libro añadido desde Buscar o Descubrir entra en la cuadrícula con un muelle.
    @Query(sort: \Book.dateAdded, order: .reverse, animation: DS.Motion.spring) private var books: [Book]
    @State private var filter: LibraryFilter = .all
    @State private var path: [BookRoute] = []
    /// El libro que se está abriendo, y desde dónde.
    @State private var opening: (route: BookRoute, frame: CGRect)?
    @State private var coverFrames = CoverFrames()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Alineadas abajo: cada portada a su proporción, apoyadas como en una estantería.
    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: DS.Layout.gridColumnSpacing, alignment: .bottom),
        count: DS.Layout.gridColumns
    )

    /// Se filtra en memoria (y no con un `#Predicate`) para que la cuadrícula
    /// pueda animar la entrada y salida de portadas al cambiar de filtro.
    private var visibleBooks: [Book] {
        books.filter(filter.includes)
    }

    private var readingNow: [Book] {
        books.filter { $0.status == .reading }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    header.screenHeaderStyle()

                    // La "portada" de la revista: lo que lees y una frase tuya.
                    if !readingNow.isEmpty {
                        ReadingNowSection(books: readingNow, coverFrames: coverFrames, openingID: opening?.route.transitionID, open: open)
                    }
                    if let pick = NotesQuoteView.pick(from: books) {
                        NotesQuoteView(book: pick.book, quote: pick.quote)
                            .padding(.vertical, DS.Spacing.xs)
                    }

                    VStack(alignment: .leading, spacing: DS.Spacing.l) {
                        UnderlineSegmentedControl(items: LibraryFilter.allCases, selection: $filter) { $0.title }

                        if visibleBooks.isEmpty {
                            LibraryEmptyState(filter: filter)
                                .transition(.opacity)
                        } else {
                            grid
                        }
                    }
                    .padding(.top, DS.Spacing.s)
                }
                .padding(.horizontal, DS.Spacing.gutter)
                .padding(.top, DS.Spacing.l)
                .padding(.bottom, DS.Spacing.xxxl)
            }
            .scrollIndicators(.hidden)
            .background(DS.Colors.canvas.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: BookRoute.self) { route in
                BookDetailView(book: route.book)
            }
        }
        .overlay {
            if let opening {
                BookOpeningOverlay(book: opening.route.book, sourceFrame: opening.frame) {
                    // La ficha entra por debajo, sin la animación de navegación.
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) { path.append(opening.route) }
                } onFinish: {
                    self.opening = nil
                }
            }
        }
    }

    /// Abre un libro: con la animación del libro que se abre si se conoce
    /// la posición de su portada; si no (o sin movimiento), navegando sin más.
    private func open(_ route: BookRoute) {
        guard opening == nil else { return }
        if !reduceMotion, let frame = coverFrames[route.transitionID] {
            opening = (route, frame)
        } else {
            path.append(route)
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
                let route = BookRoute(book: book, source: .grid)
                Button { open(route) } label: {
                    BookCoverView(book: book)
                        .recordsCoverFrame(id: route.transitionID, in: coverFrames)
                        // Mientras se abre, la portada está "fuera" de la estantería.
                        .opacity(opening?.route == route ? 0 : 1)
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityHint("Abre el detalle")
                .transition(.appear(reduceMotion: reduceMotion))
            }
        }
    }

    /// "4 leídos este año · 9 en total", como el sumario de una revista.
    private var summary: String {
        let year = Calendar.current.component(.year, from: .now)
        let readThisYear = books.filter {
            $0.status == .read && $0.dateFinished.map { Calendar.current.component(.year, from: $0) } == year
        }.count
        let total = books.count == 1 ? "1 libro en total" : "\(books.count) en total"
        guard readThisYear > 0 else { return total }
        let read = readThisYear == 1 ? "1 leído este año" : "\(readThisYear) leídos este año"
        return "\(read) · \(total)"
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
