import SwiftUI

/// Filtros como texto, sin cápsulas ni bordes: el seleccionado en tinta
/// con un trazo fino debajo que se desliza al cambiar.
struct StatusFilterBar: View {
    @Binding var selection: LibraryFilter
    @Namespace private var underline

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: DS.Spacing.l) {
                ForEach(LibraryFilter.allCases) { filter in
                    item(for: filter)
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func item(for filter: LibraryFilter) -> some View {
        let isSelected = filter == selection

        return Button {
            withAnimation(DS.Motion.snappy) { selection = filter }
        } label: {
            VStack(spacing: DS.Spacing.xs) {
                Text(filter.title)
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
