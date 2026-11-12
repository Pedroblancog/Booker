import SwiftData
import SwiftUI

/// Buscador: campo editorial, resultados asíncronos con debounce y estados
/// de inicio, carga, sin resultados y error diseñados a mano.
struct SearchView: View {
    @Environment(\.bookSearchService) private var searchService
    @Query private var library: [Book]

    @State private var model = SearchModel()
    @State private var selectedResult: BookSearchResult?
    @State private var addedCount = 0
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                header
                SearchField(text: $model.query, isLoading: model.isLoading, isFocused: $isFieldFocused)
                content
            }
            .padding(.horizontal, DS.Spacing.gutter)
            .padding(.top, DS.Spacing.l)
            .padding(.bottom, DS.Spacing.xxxl)
            .animation(DS.Motion.spring, value: model.phase)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .background(DS.Colors.canvas.ignoresSafeArea())
        .task(id: model.query) {
            await model.search(using: searchService)
        }
        .onChange(of: model.phase) { _, phase in
            if case .results(let results) = phase { prefetchCovers(for: results) }
        }
        .sheet(item: $selectedResult) { result in
            SearchResultSheet(result: result, isInLibrary: result.isInLibrary(library)) {
                addedCount += 1
            }
        }
        .sensoryFeedback(.success, trigger: addedCount)
    }

    /// En cuanto llegan los resultados se piden todas las miniaturas, también
    /// las que aún no se ven, y la portada grande de los primeros, que son
    /// los que más se abren. Así, al desplazarse o abrir uno, ya están.
    private func prefetchCovers(for results: [BookSearchResult]) {
        let thumbnails = results.compactMap(\.thumbnailURL)
        let previews = results.prefix(5).compactMap(\.previewCoverURL)
        ImageDataCache.shared.prefetch(thumbnails + previews)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("Buscar").overlineStyle()
            Text("Añade un libro")
                .font(DS.Typography.display)
                .foregroundStyle(DS.Colors.inkPrimary)
                .accessibilityAddTraits(.isHeader)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .idle where model.isLoading,
             .noResults where model.isLoading,
             .failed where model.isLoading:
            SearchLoadingView()
                .transition(.opacity)

        case .idle:
            EditorialMessageView(
                title: "¿Qué estás leyendo?",
                message: "Busca por título, autor o ISBN. Las portadas se guardan en el dispositivo para verlas sin conexión."
            )
            .transition(.opacity)

        case .results(let results):
            LazyVStack(alignment: .leading, spacing: DS.Spacing.l) {
                ForEach(results) { result in
                    Button {
                        isFieldFocused = false
                        selectedResult = result
                    } label: {
                        SearchResultRow(result: result, isInLibrary: result.isInLibrary(library))
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .opacity(model.isLoading ? 0.5 : 1)
            .transition(.opacity)

        case .noResults(let query):
            EditorialMessageView(
                title: "Nada coincide con «\(query)».",
                message: "Prueba con el apellido del autor, menos palabras o el ISBN de la contracubierta."
            )
            .transition(.opacity)

        case .failed(let isOffline):
            EditorialMessageView(
                title: isOffline ? "Sin conexión." : "La búsqueda no ha respondido.",
                message: isOffline
                    ? "Comprueba tu conexión a internet. Tu biblioteca sigue disponible sin ella."
                    : "El servicio de libros no está disponible ahora mismo. Inténtalo de nuevo en un momento.",
                actionTitle: "Reintentar"
            ) {
                Task { await model.retry(using: searchService) }
            }
            .transition(.opacity)
        }
    }
}

// MARK: - Campo de búsqueda

private struct SearchField: View {
    @Binding var text: String
    let isLoading: Bool
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(spacing: DS.Spacing.s) {
            HStack(spacing: DS.Spacing.s) {
                Image(systemName: "magnifyingglass")
                    .font(.system(.body, weight: .light))
                    .foregroundStyle(DS.Colors.inkTertiary)
                    .accessibilityHidden(true)

                TextField("Título, autor o ISBN", text: $text)
                    .font(DS.Typography.searchField)
                    .foregroundStyle(DS.Colors.inkPrimary)
                    .focused(isFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .transition(.opacity)
                } else if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(DS.Colors.inkTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Borrar búsqueda")
                    .transition(.opacity)
                }
            }
            .animation(DS.Motion.snappy, value: isLoading)

            Rectangle()
                .fill(isFocused.wrappedValue ? DS.Colors.inkPrimary : DS.Colors.inkTertiary.opacity(0.5))
                .frame(height: isFocused.wrappedValue ? 1 : 0.5)
                .animation(DS.Motion.snappy, value: isFocused.wrappedValue)
        }
    }
}

// MARK: - Carga

/// Filas fantasma que laten suavemente mientras llegan los resultados.
private struct SearchLoadingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            ForEach(0..<4, id: \.self) { index in
                HStack(alignment: .top, spacing: DS.Spacing.m) {
                    RoundedRectangle(cornerRadius: DS.Radius.cover, style: .continuous)
                        .frame(width: SearchResultRow.thumbnailWidth)
                        .aspectRatio(DS.Layout.coverAspectRatio, contentMode: .fit)
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Capsule().frame(width: index.isMultiple(of: 2) ? 180 : 140, height: 14)
                        Capsule().frame(width: 100, height: 10)
                    }
                    .padding(.top, DS.Spacing.xxs)
                }
            }
        }
        .foregroundStyle(DS.Colors.inkTertiary.opacity(0.18))
        .phaseAnimator([false, true]) { content, isDim in
            content.opacity(isDim ? 0.5 : 1)
        } animation: { _ in
            .easeInOut(duration: 0.9)
        }
        .accessibilityElement()
        .accessibilityLabel("Buscando libros")
    }
}

#Preview {
    SearchView()
        .modelContainer(SampleData.previewContainer)
}
