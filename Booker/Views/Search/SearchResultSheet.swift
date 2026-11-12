import SwiftData
import SwiftUI

/// Hoja de un resultado: portada, datos y tres formas de añadirlo.
struct SearchResultSheet: View {
    let result: BookSearchResult
    let isInLibrary: Bool
    let onAdded: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.coverImageProvider) private var coverProvider
    @Environment(\.dominantColorExtractor) private var colorExtractor

    @State private var savingStatus: BookStatus?

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xl) {
                RemoteCoverView(urls: result.previewCoverURLs, title: result.title, author: result.authorLine)
                    .frame(width: 150)
                    .padding(.top, DS.Spacing.xl)

                VStack(spacing: DS.Spacing.xs) {
                    Text(result.title)
                        .font(DS.Typography.bookTitle)
                        .foregroundStyle(DS.Colors.inkPrimary)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)

                    if let subtitle = result.subtitle {
                        Text(subtitle)
                            .font(DS.Typography.meta)
                            .foregroundStyle(DS.Colors.inkSecondary)
                            .multilineTextAlignment(.center)
                    }

                    Text(byline)
                        .font(DS.Typography.meta)
                        .foregroundStyle(DS.Colors.inkSecondary)
                        .multilineTextAlignment(.center)
                }

                if isInLibrary {
                    Label("Ya está en tu biblioteca", systemImage: "checkmark")
                        .font(DS.Typography.meta)
                        .foregroundStyle(DS.Colors.inkSecondary)
                } else {
                    actions
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, DS.Spacing.gutter)
            .padding(.bottom, DS.Spacing.xl)
        }
        .scrollIndicators(.hidden)
        .background(DS.Colors.canvas.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(savingStatus != nil)
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("Añadir como").overlineStyle()

            VStack(spacing: DS.Spacing.xs) {
                addButton("Quiero leerlo", status: .toRead)
                addButton("Lo estoy leyendo", status: .reading)
                addButton("Ya lo he leído", status: .read)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func addButton(_ title: String, status: BookStatus) -> some View {
        Button {
            Task { await add(as: status) }
        } label: {
            HStack {
                Text(title)
                    .font(DS.Typography.menuSelected)
                Spacer()
                if savingStatus == status {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.right")
                        .font(.system(.footnote, weight: .light))
                }
            }
            .foregroundStyle(DS.Colors.inkPrimary)
            .padding(.horizontal, DS.Spacing.m)
            .padding(.vertical, DS.Spacing.m)
            .background(DS.Colors.inkPrimary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(savingStatus != nil)
        .opacity(savingStatus == nil || savingStatus == status ? 1 : 0.4)
    }

    // MARK: - Datos

    private var byline: String {
        [result.authors.isEmpty ? nil : result.authorLine, result.publishedYear.map(String.init)]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private func add(as status: BookStatus) async {
        savingStatus = status
        let importer = BookImporter(context: modelContext, covers: coverProvider, colors: colorExtractor)
        await importer.add(result, as: status)
        onAdded()
        dismiss()
    }
}
