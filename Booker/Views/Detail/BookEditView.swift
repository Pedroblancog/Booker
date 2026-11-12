import SwiftUI

/// Hoja para corregir título, autores y fecha de fin.
/// Trabaja sobre un borrador: si se cancela, el libro no cambia.
struct BookEditView: View {
    let book: Book
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var authors: String
    @State private var dateFinished: Date

    init(book: Book, onSave: @escaping () -> Void) {
        self.book = book
        self.onSave = onSave
        _title = State(initialValue: book.title)
        _authors = State(initialValue: book.authors.joined(separator: ", "))
        _dateFinished = State(initialValue: book.dateFinished ?? .now)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    field("Título") {
                        TextField("Título del libro", text: $title, axis: .vertical)
                            .font(DS.Typography.bookTitle)
                    }

                    field("Autores") {
                        TextField("Separados por comas", text: $authors)
                            .font(DS.Typography.body)
                            .textInputAutocapitalization(.words)
                    }

                    if book.status == .read {
                        field("Terminado") {
                            DatePicker("Fecha de fin", selection: $dateFinished, in: ...Date.now, displayedComponents: .date)
                                .labelsHidden()
                        }
                    }
                }
                .foregroundStyle(DS.Colors.inkPrimary)
                .padding(DS.Spacing.gutter)
            }
            .background(DS.Colors.canvas.ignoresSafeArea())
            .navigationTitle("Editar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save)
                        .disabled(trimmedTitle.isEmpty)
                }
            }
            .tint(DS.Colors.inkPrimary)
        }
    }

    /// Campo con rótulo encima y un trazo finísimo debajo.
    private func field(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(label).overlineStyle()
            content()
            Rectangle()
                .fill(DS.Colors.inkTertiary.opacity(0.4))
                .frame(height: 0.5)
        }
    }

    private func save() {
        book.title = trimmedTitle
        book.authors = authors
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if book.status == .read {
            book.dateFinished = dateFinished
        }
        onSave()
        dismiss()
    }
}
