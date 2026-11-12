import SwiftData
import SwiftUI

/// Qué comentario se está escribiendo: uno nuevo o uno que ya existe.
enum CommentEditorTarget: Identifiable {
    case new
    case existing(ReadingNote)

    var id: String {
        switch self {
        case .new: "new"
        case .existing(let note): note.id.uuidString
        }
    }

    var note: ReadingNote? {
        if case .existing(let note) = self { return note }
        return nil
    }
}

/// Mientras se lee: un botón para añadir un comentario sobre lo leído y,
/// debajo, la lista de comentarios en dos columnas (página y mensaje).
/// Tocar uno lo abre completo en un pop-up.
struct ReadingNotesSection: View {
    let book: Book
    @Binding var editor: CommentEditorTarget?
    @Binding var expanded: ReadingNote?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// La columna de página crece con el tamaño de letra.
    @ScaledMetric(relativeTo: .subheadline) private var pageColumnWidth: CGFloat = 52

    var body: some View {
        let notes = book.sortedReadingNotes

        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            Text("Comentarios")
                .overlineStyle()
                .accessibilityAddTraits(.isHeader)

            addButton

            if !notes.isEmpty {
                VStack(spacing: 0) {
                    header
                    ForEach(notes) { note in
                        row(note)
                            .transition(.opacity)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(reduceMotion ? DS.Motion.reduced : DS.Motion.spring, value: notes.map(\.id))
    }

    private var addButton: some View {
        Button {
            editor = .new
        } label: {
            HStack {
                Text("Añadir comentario")
                    .font(DS.Typography.menuSelected)
                Spacer()
                Image(systemName: "plus")
                    .font(.system(.footnote, weight: .light))
            }
            .foregroundStyle(DS.Colors.inkPrimary)
            .padding(.horizontal, DS.Spacing.m)
            .padding(.vertical, DS.Spacing.m)
            .background(DS.Colors.inkPrimary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var header: some View {
        HStack(spacing: DS.Spacing.m) {
            Text("Pág.")
                .frame(width: pageColumnWidth, alignment: .leading)
            Text("Comentario")
            Spacer(minLength: 0)
        }
        .font(DS.Typography.caption)
        .foregroundStyle(DS.Colors.inkTertiary)
        .padding(.bottom, DS.Spacing.xs)
        .accessibilityHidden(true)
    }

    private func row(_ note: ReadingNote) -> some View {
        Button {
            withAnimation(reduceMotion ? DS.Motion.reduced : .spring(duration: 0.35, bounce: 0.15)) {
                expanded = note
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.m) {
                Text(note.page.map(String.init) ?? "—")
                    .font(.system(.subheadline, design: .serif).monospacedDigit())
                    .foregroundStyle(DS.Colors.accent)
                    .frame(width: pageColumnWidth, alignment: .leading)

                Text(note.text)
                    .font(DS.Typography.notes)
                    .foregroundStyle(DS.Colors.inkPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, DS.Spacing.s)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(DS.Colors.inkTertiary.opacity(0.3))
                    .frame(height: 0.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(note.accessibilityLabel)
        .accessibilityHint("Muestra el comentario completo")
        .contextMenu {
            Button("Editar", systemImage: "pencil") { editor = .existing(note) }
            Button("Eliminar", systemImage: "trash", role: .destructive) { book.removeReadingNote(note) }
        }
    }
}

// MARK: - Pop-up

/// El comentario completo, ampliado, sobre la ficha atenuada.
struct CommentPopup: View {
    let note: ReadingNote
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)
                .accessibilityLabel("Cerrar")
                .accessibilityAddTraits(.isButton)

            VStack(alignment: .leading, spacing: DS.Spacing.l) {
                HStack(alignment: .firstTextBaseline) {
                    Text(note.page.map { "Página \($0)" } ?? "Sin página")
                        .overlineStyle()
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(.footnote, weight: .medium))
                            .foregroundStyle(DS.Colors.inkSecondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cerrar")
                    .padding(-DS.Spacing.s)
                }

                ScrollView {
                    Text(note.text)
                        .font(DS.Typography.pullQuote)
                        .foregroundStyle(DS.Colors.inkPrimary)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxHeight: 360)
                .fixedSize(horizontal: false, vertical: true)

                Text(note.dateAdded.formatted(.dateTime.day().month(.wide).year()))
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.inkTertiary)

                HStack(spacing: DS.Spacing.l) {
                    Button("Editar", action: onEdit)
                    Button("Eliminar", role: .destructive, action: onDelete)
                }
                .font(DS.Typography.menu)
                .foregroundStyle(DS.Colors.inkSecondary)
                .buttonStyle(.plain)
            }
            .padding(DS.Spacing.l)
            .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .cardStyle()
            .padding(.horizontal, DS.Spacing.gutter)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
    }
}

// MARK: - Editor

/// Hoja para escribir o corregir un comentario: página actual y comentario.
struct CommentEditor: View {
    let book: Book
    let note: ReadingNote?
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var page: String
    @State private var text: String
    @FocusState private var focus: Field?

    private enum Field { case page, text }

    init(book: Book, note: ReadingNote?, onSave: @escaping () -> Void) {
        self.book = book
        self.note = note
        self.onSave = onSave
        _page = State(initialValue: note?.page.map(String.init) ?? "")
        _text = State(initialValue: note?.text ?? "")
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    field("Página actual") {
                        TextField("Por ejemplo, 142", text: $page)
                            .font(DS.Typography.bookTitle)
                            .keyboardType(.numberPad)
                            .focused($focus, equals: .page)
                    }

                    field("Comentario") {
                        TextField("¿Qué te ha parecido lo que has leído?", text: $text, axis: .vertical)
                            .font(DS.Typography.notes)
                            .lineLimit(4...)
                            .focused($focus, equals: .text)
                    }
                }
                .padding(DS.Spacing.gutter)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(DS.Colors.canvas.ignoresSafeArea())
            .navigationTitle(note == nil ? "Nuevo comentario" : "Editar comentario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save)
                        .disabled(trimmedText.isEmpty)
                }
            }
            .onChange(of: page) { _, value in
                // Solo cifras, y una página razonable.
                let digits = String(value.filter(\.isNumber).prefix(5))
                if digits != value { page = digits }
            }
            .onAppear { focus = note == nil ? .page : .text }
        }
        .tint(DS.Colors.inkPrimary)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func field(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(label).overlineStyle()
            content()
                .foregroundStyle(DS.Colors.inkPrimary)
            Rectangle()
                .fill(DS.Colors.inkTertiary.opacity(0.4))
                .frame(height: 0.5)
        }
    }

    private func save() {
        let pageNumber = Int(page).flatMap { $0 > 0 ? $0 : nil }
        if let note {
            note.page = pageNumber
            note.text = trimmedText
        } else {
            book.addReadingNote(page: pageNumber, text: trimmedText)
        }
        try? modelContext.save()
        onSave()
        dismiss()
    }
}
