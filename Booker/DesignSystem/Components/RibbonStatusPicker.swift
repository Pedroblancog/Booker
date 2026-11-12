import SwiftUI

/// Selector de estado con marcapáginas de tela: tres cintas cuelgan del
/// canto del libro; la del estado elegido baja hasta abajo y las demás se
/// recogen. Para VoiceOver es un selector normal de tres opciones.
struct RibbonStatusPicker: View {
    @Binding var selection: BookStatus

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// El orden natural de una lectura.
    static let order: [BookStatus] = [.toRead, .reading, .read]

    var body: some View {
        VStack(spacing: 0) {
            // El canto superior del libro, del que cuelgan las cintas.
            Rectangle()
                .fill(DS.Colors.inkPrimary.opacity(0.12))
                .frame(height: 1)
                .accessibilityHidden(true)

            HStack(alignment: .top, spacing: 0) {
                ForEach(Self.order) { status in
                    ribbon(for: status)
                }
            }
        }
    }

    private func ribbon(for status: BookStatus) -> some View {
        let isSelected = selection == status
        return Button {
            guard selection != status else { return }
            // Al soltarla, la cinta cae y rebota un poco, como la tela.
            withAnimation(reduceMotion ? DS.Motion.reduced : .spring(duration: 0.6, bounce: 0.38)) {
                selection = status
            }
        } label: {
            VStack(spacing: DS.Spacing.xs) {
                Ribbon(isSelected: isSelected)
                    .frame(width: 18, height: isSelected ? 88 : 30)

                Text(status.title)
                    .font(isSelected ? DS.Typography.menuSelected : DS.Typography.menu)
                    .foregroundStyle(isSelected ? DS.Colors.inkPrimary : DS.Colors.inkTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, DS.Spacing.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(status.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isSelected ? "" : "Marca el libro como \(status.title.lowercased())")
    }
}

/// Una cinta de tela con el extremo en cola de golondrina.
private struct Ribbon: View {
    let isSelected: Bool

    var body: some View {
        let shape = SwallowtailRibbon()
        ZStack {
            shape.fill(isSelected ? DS.Colors.accent : DS.Colors.inkTertiary.opacity(0.35))
            // Brillo de la tela: los bordes más oscuros, el centro con luz.
            shape.fill(
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.22), location: 0),
                        .init(color: .white.opacity(isSelected ? 0.22 : 0.10), location: 0.42),
                        .init(color: .black.opacity(0.12), location: 1),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
        .shadow(color: .black.opacity(isSelected ? 0.18 : 0), radius: 3, x: 1, y: 2)
        .accessibilityHidden(true)
    }
}

private struct SwallowtailRibbon: Shape {
    func path(in rect: CGRect) -> Path {
        let notch = min(rect.width * 0.5, rect.height * 0.3)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - notch))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    @Previewable @State var status = BookStatus.reading
    RibbonStatusPicker(selection: $status)
        .padding(DS.Spacing.gutter)
        .background(DS.Colors.canvas)
}
