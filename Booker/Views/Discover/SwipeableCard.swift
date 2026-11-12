import SwiftUI

enum SwipeDirection: Equatable {
    /// Derecha: guardar como pendiente.
    case save
    /// Izquierda: descartar.
    case discard

    var sign: CGFloat { self == .save ? 1 : -1 }
}

/// Envuelve una tarjeta para poder arrastrarla. Pasado el umbral vibra
/// una vez; al soltar sale volando hacia ese lado o vuelve a su sitio con
/// un muelle. También se puede lanzar desde fuera con `programmaticSwipe`
/// (los botones de debajo).
struct SwipeableCard<Content: View>: View {
    var programmaticSwipe: SwipeDirection?
    let onSwipe: (SwipeDirection) -> Void
    @ViewBuilder let content: Content

    @State private var offset: CGSize = .zero
    @State private var isPastThreshold = false
    @State private var isLeaving = false
    @State private var opacity = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let threshold: CGFloat = 110

    var body: some View {
        content
            .overlay(alignment: .topLeading) {
                stamp("Guardar", color: DS.Colors.accent, rotation: -10)
                    .opacity(Double(max(0, offset.width) / threshold))
            }
            .overlay(alignment: .topTrailing) {
                stamp("Descartar", color: DS.Colors.inkSecondary, rotation: 10)
                    .opacity(Double(max(0, -offset.width) / threshold))
            }
            .offset(x: offset.width, y: offset.height * 0.15)
            // El giro es decorativo: con "Reducir movimiento" la tarjeta solo se desplaza.
            .rotationEffect(.degrees(reduceMotion ? 0 : Double(offset.width / 24)), anchor: .bottom)
            .opacity(opacity)
            .gesture(drag)
            .sensoryFeedback(.impact(weight: .light), trigger: isPastThreshold) { _, isPast in isPast }
            .onChange(of: programmaticSwipe) { _, direction in
                if let direction { fly(direction) }
            }
    }

    private var drag: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isLeaving else { return }
                offset = value.translation
                isPastThreshold = abs(value.translation.width) > threshold
            }
            .onEnded { value in
                guard !isLeaving else { return }
                let width = value.translation.width
                let predicted = value.predictedEndTranslation.width
                if abs(width) > threshold || abs(predicted) > threshold * 2.5 {
                    fly(width > 0 ? .save : .discard)
                } else {
                    withAnimation(DS.Motion.spring) { offset = .zero }
                    isPastThreshold = false
                }
            }
    }

    /// Sale volando hacia ese lado; con "Reducir movimiento", se funde sin cruzar la pantalla.
    private func fly(_ direction: SwipeDirection) {
        guard !isLeaving else { return }
        isLeaving = true
        if reduceMotion {
            withAnimation(DS.Motion.reduced, completionCriteria: .logicallyComplete) {
                opacity = 0
            } completion: {
                onSwipe(direction)
            }
        } else {
            withAnimation(.spring(duration: 0.35, bounce: 0), completionCriteria: .logicallyComplete) {
                offset = CGSize(width: direction.sign * 700, height: offset.height + 40)
            } completion: {
                onSwipe(direction)
            }
        }
    }

    private func stamp(_ text: String, color: Color, rotation: Double) -> some View {
        Text(text)
            .font(DS.Typography.stamp)
            .textCase(.uppercase)
            .tracking(2)
            .foregroundStyle(color)
            .padding(.horizontal, DS.Spacing.s)
            .padding(.vertical, DS.Spacing.xs)
            .background(DS.Colors.surface.opacity(0.85), in: Capsule())
            .rotationEffect(.degrees(rotation))
            .padding(DS.Spacing.l)
            .accessibilityHidden(true)
    }
}
