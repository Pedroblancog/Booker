import SwiftUI

/// Cinco estrellas finas. Tocar una estrella fija la puntuación; tocar
/// la que ya está seleccionada la borra. Vibra ligeramente al cambiar.
/// Para VoiceOver es un único control ajustable deslizando arriba y abajo.
struct StarRatingView: View {
    let rating: Int?
    let onChange: (Int?) -> Void

    private var current: Int { rating ?? 0 }

    var body: some View {
        HStack(spacing: DS.Spacing.xxs) {
            ForEach(1...5, id: \.self) { value in
                star(value)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: rating)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Puntuación")
        .accessibilityValue(rating.map { "\($0) de 5 estrellas" } ?? "Sin puntuar")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onChange(min(current + 1, 5))
            case .decrement: onChange(current <= 1 ? nil : current - 1)
            @unknown default: break
            }
        }
    }

    private func star(_ value: Int) -> some View {
        let isFilled = value <= current

        return Button {
            onChange(value == rating ? nil : value)
        } label: {
            Image(systemName: isFilled ? "star.fill" : "star")
                .font(.system(.title3, weight: .ultraLight))
                .foregroundStyle(isFilled ? DS.Colors.inkPrimary : DS.Colors.inkTertiary)
                .symbolEffect(.bounce, value: value == rating ? rating : nil)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @State var rating: Int? = 3
    StarRatingView(rating: rating) { rating = $0 }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colors.canvas)
}
