import SwiftUI

/// Selector de opciones como texto, sin cápsulas ni bordes: la opción
/// seleccionada en tinta con un trazo fino debajo que se desliza al cambiar.
/// Se usa en los filtros de la Biblioteca y en el estado del detalle.
struct UnderlineSegmentedControl<Item: Identifiable & Hashable>: View {
    let items: [Item]
    @Binding var selection: Item
    let title: (Item) -> String

    @Namespace private var underline

    var body: some View {
        // Con texto grande las opciones no caben: la fila se desplaza y se
        // asegura de que la seleccionada esté a la vista.
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: DS.Spacing.l) {
                    ForEach(items) { item in
                        segment(for: item)
                            .id(item.id)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .onAppear { proxy.scrollTo(selection.id) }
            .onChange(of: selection) { _, newValue in
                withAnimation(DS.Motion.snappy) { proxy.scrollTo(newValue.id) }
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func segment(for item: Item) -> some View {
        let isSelected = item == selection

        return Button {
            withAnimation(DS.Motion.snappy) { selection = item }
        } label: {
            VStack(spacing: DS.Spacing.xs) {
                Text(title(item))
                    .font(isSelected ? DS.Typography.menuSelected : DS.Typography.menu)
                    .foregroundStyle(isSelected ? DS.Colors.inkPrimary : DS.Colors.inkTertiary)

                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(DS.Colors.inkPrimary)
                            .matchedGeometryEffect(id: "underline", in: underline)
                    }
                }
                .frame(height: 1.5)
            }
            .fixedSize()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
