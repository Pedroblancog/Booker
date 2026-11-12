import SwiftUI

/// Mensaje para estados vacíos y de error: un trazo corto, una frase en
/// serif cursiva, una explicación ligera y, opcionalmente, una acción.
struct EditorialMessageView: View {
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            Rectangle()
                .fill(DS.Colors.inkTertiary)
                .frame(width: 28, height: 1)

            VStack(alignment: .leading, spacing: DS.Spacing.m) {
                Text(title)
                    .font(DS.Typography.emptyState)
                    .foregroundStyle(DS.Colors.inkPrimary)

                Text(message)
                    .font(DS.Typography.meta)
                    .foregroundStyle(DS.Colors.inkSecondary)
            }
            .accessibilityElement(children: .combine)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(DS.Typography.menuSelected)
                    .foregroundStyle(DS.Colors.inkPrimary)
                    .buttonStyle(.plain)
                    .padding(.top, DS.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, DS.Spacing.xxl)
    }
}
