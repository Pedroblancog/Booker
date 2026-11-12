import SwiftUI

/// Cinco estrellas finas con medias estrellas. Tocar la mitad izquierda
/// de una estrella da media; la derecha, la estrella entera. Tocar el valor
/// que ya está puesto lo borra. Vibra ligeramente al cambiar.
/// Para VoiceOver es un único control ajustable en pasos de media estrella.
struct StarRatingView: View {
    let rating: Double?
    let onChange: (Double?) -> Void

    private var current: Double { rating ?? 0 }

    var body: some View {
        HStack(spacing: DS.Spacing.xxs) {
            ForEach(1...5, id: \.self) { position in
                star(position)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: rating)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Puntuación")
        .accessibilityValue(rating.map { "\(Book.formattedRating($0)) de 5 estrellas" } ?? "Sin puntuar")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onChange(min(current + 0.5, 5))
            case .decrement: onChange(current <= 0.5 ? nil : current - 0.5)
            @unknown default: break
            }
        }
    }

    private func star(_ position: Int) -> some View {
        let value = Double(position)
        let symbol = current >= value ? "star.fill" : current >= value - 0.5 ? "star.leadinghalf.filled" : "star"
        let isLit = current >= value - 0.5

        return Image(systemName: symbol)
            .font(.system(.title3, weight: .ultraLight))
            .foregroundStyle(isLit ? DS.Colors.inkPrimary : DS.Colors.inkTertiary)
            .symbolEffect(.bounce, value: rating.map { $0 > value - 1 && $0 <= value } == true ? rating : nil)
            .frame(minWidth: 44, minHeight: 44)
            .overlay {
                // Dos zonas táctiles: mitad izquierda (media) y derecha (entera).
                HStack(spacing: 0) {
                    tapZone(value - 0.5)
                    tapZone(value)
                }
            }
    }

    private func tapZone(_ value: Double) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture { onChange(value == rating ? nil : value) }
    }
}

#Preview {
    @Previewable @State var rating: Double? = 3.5
    StarRatingView(rating: rating) { rating = $0 }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colors.canvas)
}
