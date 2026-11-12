import SwiftData
import SwiftUI

/// Descubrir: a partir de los libros leídos con 4 estrellas o más, muestra
/// tres recomendaciones verificadas en tarjetas. Derecha guarda como
/// pendiente; izquierda descarta.
struct DiscoverView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.recommendationService) private var recommendationService
    @Environment(\.bookSearchService) private var searchService
    @Environment(\.coverImageProvider) private var coverProvider
    @Environment(\.dominantColorExtractor) private var colorExtractor
    @Query private var library: [Book]

    @State private var model = DiscoverModel()
    @State private var pendingSwipe: SwipeDirection?
    @State private var savedCount = 0
    @State private var discardedCount = 0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var engine: RecommendationEngine {
        RecommendationEngine(recommender: recommendationService, search: searchService)
    }

    private var favoritesCount: Int {
        DiscoverModel.favorites(in: library).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            header.screenHeaderStyle()
                .padding(.horizontal, DS.Spacing.gutter)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(.top, DS.Spacing.l)
        .background(DS.Colors.canvas.ignoresSafeArea())
        .animation(DS.Motion.spring, value: model.phase)
        .task(id: favoritesCount) {
            await model.refreshIfNeeded(library: library, engine: engine)
        }
        .onChange(of: model.cards.map(\.id)) { _, _ in
            ImageDataCache.shared.prefetch(model.cards.compactMap(\.book.previewCoverURLs.first))
        }
        .sensoryFeedback(.success, trigger: savedCount)
        .sensoryFeedback(.impact(weight: .light), trigger: discardedCount)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("Descubrir").overlineStyle()
            Text("Para ti")
                .font(DS.Typography.display)
                .foregroundStyle(DS.Colors.inkPrimary)
                .accessibilityAddTraits(.isHeader)
            if favoritesCount >= DiscoverModel.minimumFavorites {
                Text(favoritesCount == 1 ? "A partir de tu libro favorito" : "A partir de tus \(favoritesCount) favoritos")
                    .font(DS.Typography.meta)
                    .foregroundStyle(DS.Colors.inkSecondary)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .idle, .loading:
            DiscoverLoadingView()
                .padding(.horizontal, DS.Spacing.gutter)
                .padding(.bottom, DS.Spacing.xl)
                .transition(.opacity)

        case .needsRatings(let have):
            message(
                "Puntúa unos libros más.",
                "Descubrir se basa en los libros que has leído y puntuado con 4 estrellas o más. Llevas \(have) de \(DiscoverModel.minimumFavorites)."
            )

        case .cards:
            cardStack

        case .finished:
            message(
                "Eso es todo por ahora.",
                "Las que guardaste te esperan en Pendientes.",
                action: ("Pedir otras tres", reload)
            )

        case .failed(.notConfigured):
            message(
                "Descubrir aún no está conectado.",
                "Las recomendaciones salen de un servidor propio que todavía no está configurado para esta versión de la app."
            )

        case .failed(.offline):
            message(
                "Sin conexión.",
                "Las recomendaciones necesitan internet. Tu biblioteca sigue disponible sin él.",
                action: ("Reintentar", reload)
            )

        case .failed(.unavailable):
            message(
                "El librero no responde.",
                "No hemos podido preparar recomendaciones ahora mismo. Inténtalo de nuevo en un momento.",
                action: ("Reintentar", reload)
            )
        }
    }

    private var cardStack: some View {
        VStack(spacing: DS.Spacing.l) {
            ZStack {
                ForEach(Array(model.cards.prefix(3).enumerated()).reversed(), id: \.element.id) { depth, card in
                    let isTop = depth == 0
                    SwipeableCard(programmaticSwipe: isTop ? pendingSwipe : nil) { direction in
                        handleSwipe(direction)
                    } content: {
                        RecommendationCard(recommendation: card)
                    }
                    // Las de detrás asoman por arriba, más estrechas, como una pila.
                    .padding(.horizontal, CGFloat(depth) * 14)
                    .offset(y: CGFloat(depth) * -12)
                    .allowsHitTesting(isTop)
                    .accessibilityHidden(!isTop)
                    .accessibilityAction(named: "Guardar en pendientes") { handleSwipe(.save) }
                    .accessibilityAction(named: "Descartar") { handleSwipe(.discard) }
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, DS.Spacing.gutter)
            .padding(.top, DS.Spacing.l)

            HStack(spacing: DS.Spacing.s) {
                actionButton("Descartar", systemImage: "xmark", direction: .discard)
                if dynamicTypeSize.isAccessibilitySize {
                    Spacer()
                } else {
                    Text("Desliza para decidir")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.inkTertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                }
                actionButton("Guardar", systemImage: "bookmark", direction: .save)
            }
            .padding(.horizontal, DS.Spacing.gutter)
            .padding(.bottom, DS.Spacing.l)
        }
    }

    private func actionButton(_ title: String, systemImage: String, direction: SwipeDirection) -> some View {
        Button {
            pendingSwipe = direction
        } label: {
            // Con texto de accesibilidad, solo el icono: el nombre sigue llegando a VoiceOver.
            Label(title, systemImage: systemImage)
                .labelStyle(AdaptiveLabelStyle(iconOnly: dynamicTypeSize.isAccessibilitySize))
                .font(DS.Typography.menuSelected)
                .foregroundStyle(direction == .save ? DS.Colors.inkPrimary : DS.Colors.inkSecondary)
                .padding(.horizontal, DS.Spacing.m)
                .padding(.vertical, DS.Spacing.s)
                .background(DS.Colors.inkPrimary.opacity(0.05), in: Capsule())
                .fixedSize()
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(pendingSwipe != nil)
    }

    private func message(_ title: String, _ text: String, action: (String, () -> Void)? = nil) -> some View {
        EditorialMessageView(title: title, message: text, actionTitle: action?.0, action: action?.1)
            .padding(.horizontal, DS.Spacing.gutter)
            .transition(.opacity)
    }

    // MARK: - Acciones

    private func handleSwipe(_ direction: SwipeDirection) {
        pendingSwipe = nil
        guard let card = withAnimation(DS.Motion.spring, { model.takeTopCard() }) else { return }

        switch direction {
        case .discard:
            discardedCount += 1
        case .save:
            savedCount += 1
            let importer = BookImporter(context: modelContext, covers: coverProvider, colors: colorExtractor)
            Task { _ = await importer.add(card.book, as: .toRead, source: .recommendation) }
        }
    }

    private func reload() {
        Task { await model.load(library: library, engine: engine) }
    }
}

/// Icono y texto, o solo icono. `Label` conserva el texto como etiqueta accesible.
private struct AdaptiveLabelStyle: LabelStyle {
    let iconOnly: Bool

    func makeBody(configuration: Configuration) -> some View {
        if iconOnly {
            configuration.icon
        } else {
            HStack(spacing: DS.Spacing.xs) {
                configuration.icon
                configuration.title
            }
        }
    }
}

// MARK: - Carga

/// Una tarjeta fantasma que late mientras el librero piensa.
private struct DiscoverLoadingView: View {
    var body: some View {
        VStack(spacing: DS.Spacing.l) {
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(DS.Colors.surface)
                .overlay {
                    VStack(spacing: DS.Spacing.l) {
                        RoundedRectangle(cornerRadius: DS.Radius.cover, style: .continuous)
                            .fill(DS.Colors.inkTertiary.opacity(0.15))
                            .aspectRatio(DS.Layout.coverAspectRatio, contentMode: .fit)
                            .frame(width: 130)
                        Capsule().fill(DS.Colors.inkTertiary.opacity(0.15)).frame(width: 180, height: 16)
                        Capsule().fill(DS.Colors.inkTertiary.opacity(0.12)).frame(width: 120, height: 12)
                    }
                    .loadingPulse()
                }
                .cardStyle()

            Text("Buscando en las estanterías…")
                .font(DS.Typography.reason)
                .foregroundStyle(DS.Colors.inkSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preparando recomendaciones")
    }
}

#Preview("Descubrir") {
    DiscoverView()
        .modelContainer(SampleData.previewContainer)
        .environment(\.recommendationService, PreviewRecommendationService())
}

/// Recomendaciones fijas para el #Preview, sin red.
private struct PreviewRecommendationService: RecommendationService {
    func candidates(for favorites: [FavoriteBook], excluding: [String], count: Int) async throws -> [RecommendationCandidate] {
        [RecommendationCandidate(title: "Nada", author: "Carmen Laforet",
                                 reason: "La misma mirada a una casa que se derrumba que te atrapó en Pedro Páramo, pero en la Barcelona de posguerra.")]
    }
}
