import SwiftData
import SwiftUI

/// Ficha de un libro, a la que se llega abriéndolo desde la biblioteca:
/// arriba la portada, con título y autor; debajo, los marcapáginas de estado
/// y lo que corresponde a cada uno (nada si está pendiente, comentarios mientras
/// se lee, valoración y conclusión al terminarlo) y acciones discretas de
/// editar y eliminar.
struct BookDetailView: View {
    @Bindable var book: Book

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dominantColorExtractor) private var colorExtractor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isEditing = false
    @State private var isConfirmingDelete = false
    @State private var saveCount = 0
    @State private var commentEditor: CommentEditorTarget?
    /// El comentario abierto en el pop-up.
    @State private var expandedComment: ReadingNote?
    @FocusState private var isEditingNotes: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xxl) {
                header
                statusSection
                stageSection
                footer
            }
            .padding(.horizontal, DS.Spacing.gutter)
            .padding(.top, DS.Spacing.m)
            .padding(.bottom, DS.Spacing.xxxl)
            .animation(DS.Motion.spring, value: book.status)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(TintedBackground(colorHex: book.dominantColorHex))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            // Solo mientras se escribe la conclusión: si no, aparecería también
            // sobre el teclado de la hoja de comentarios.
            if isEditingNotes {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Listo") { isEditingNotes = false }
                }
            }
        }
        .tint(DS.Colors.inkPrimary)
        .sensoryFeedback(.selection, trigger: book.status)
        .sheet(isPresented: $isEditing) {
            BookEditView(book: book) {
                try? modelContext.save()
                saveCount += 1
            }
        }
        .confirmationDialog(
            "¿Eliminar «\(book.title)»?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Eliminar libro", role: .destructive, action: deleteBook)
        } message: {
            Text("Se borrarán también tu valoración, tu conclusión y tus comentarios.")
        }
        .sensoryFeedback(.success, trigger: saveCount)
        .onChange(of: isEditingNotes) { _, isFocused in
            if !isFocused { try? modelContext.save() }
        }
        .task {
            await colorExtractor.assignDominantColorIfNeeded(to: book)
        }
        .onAppear(perform: moveLegacyNotesToComment)
        .sheet(item: $commentEditor) { target in
            CommentEditor(book: book, note: target.note) { saveCount += 1 }
        }
        .overlay {
            if let note = expandedComment {
                CommentPopup(note: note) {
                    closeComment()
                    commentEditor = .existing(note)
                } onDelete: {
                    closeComment()
                    book.removeReadingNote(note)
                } onClose: {
                    closeComment()
                }
                .transition(.opacity.combined(with: .scale(scale: reduceMotion ? 1 : 0.94)))
            }
        }
        // La barra de pestañas se aparta mientras el pop-up está abierto.
        .toolbar(expandedComment == nil ? .automatic : .hidden, for: .tabBar)
    }

    private func closeComment() {
        withAnimation(reduceMotion ? DS.Motion.reduced : .spring(duration: 0.3, bounce: 0)) {
            expandedComment = nil
        }
    }

    // MARK: - Secciones

    /// La portada, protagonista, y debajo título y autor. El estado ya lo
    /// dicen los marcapáginas.
    private var header: some View {
        VStack(spacing: DS.Spacing.s) {
            BookCoverView(book: book)
                .containerRelativeFrame(.horizontal) { width, _ in width * 0.52 }
                .padding(.bottom, DS.Spacing.l)

            Text(book.title)
                .font(DS.Typography.detailTitle)
                .foregroundStyle(DS.Colors.inkPrimary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            if !book.authors.isEmpty {
                Text(book.authorLine)
                    .font(DS.Typography.meta)
                    .foregroundStyle(DS.Colors.inkSecondary)
                    .multilineTextAlignment(.center)
            }

            Rectangle()
                .fill(DS.Colors.accent)
                .frame(width: 24, height: 1)
                .padding(.top, DS.Spacing.xs)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DS.Spacing.l)
    }

    /// Marcapáginas: la cinta del estado elegido cuelga hasta abajo.
    private var statusSection: some View {
        DetailSection("Estado") {
            RibbonStatusPicker(selection: $book.status)
        }
    }

    /// Lo que se puede hacer en cada momento de la lectura.
    @ViewBuilder
    private var stageSection: some View {
        switch book.status {
        case .toRead:
            // Pendiente: aún no hay nada que apuntar.
            EmptyView()
        case .reading:
            ReadingNotesSection(book: book, editor: $commentEditor, expanded: $expandedComment)
                .transition(.appear(reduceMotion: reduceMotion))
        case .read:
            VStack(spacing: DS.Spacing.xxl) {
                DetailSection("Tu valoración") {
                    StarRatingView(rating: book.rating) { book.setRating($0) }
                }
                conclusionSection
            }
            .transition(.appear(reduceMotion: reduceMotion))
        }
    }

    /// La conclusión, como una cita de revista: cursiva y un filete dorado.
    private var conclusionSection: some View {
        DetailSection("Conclusión") {
            HStack(alignment: .top, spacing: DS.Spacing.m) {
                Rectangle()
                    .fill(DS.Colors.accent)
                    .frame(width: 1.5)
                    .accessibilityHidden(true)

                TextField("¿Con qué te quedas de este libro?", text: notesBinding, axis: .vertical)
                    .font(DS.Typography.reason)
                    .foregroundStyle(DS.Colors.inkPrimary)
                    .lineSpacing(4)
                    .lineLimit(3...)
                    .focused($isEditingNotes)
                    .accessibilityLabel("Conclusión")
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Antes había una sola nota libre por libro. En un libro que se está
    /// leyendo esa nota pasa a ser su primer comentario, para que no quede oculta.
    private func moveLegacyNotesToComment() {
        guard book.status == .reading, book.readingNotes.isEmpty,
              let notes = book.notes, book.addReadingNote(page: nil, text: notes) != nil
        else { return }
        book.notes = nil
        try? modelContext.save()
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                ForEach(metadataLines, id: \.self) { line in
                    Text(line)
                }
            }
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Colors.inkTertiary)

            HStack(spacing: DS.Spacing.l) {
                Button("Editar") { isEditing = true }
                Button("Eliminar", role: .destructive) { isConfirmingDelete = true }
            }
            .font(DS.Typography.menu)
            .foregroundStyle(DS.Colors.inkSecondary)
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Datos

    /// `TextField` necesita un `String`; las notas vacías se guardan como `nil`.
    private var notesBinding: Binding<String> {
        Binding(
            get: { book.notes ?? "" },
            set: { book.notes = $0.isEmpty ? nil : $0 }
        )
    }

    private var metadataLines: [String] {
        var lines = ["Añadido el \(book.dateAdded.formatted(.dateTime.day().month(.wide).year()))"]
        if let finished = book.dateFinished {
            lines.append("Terminado en \(finished.formatted(.dateTime.month(.wide).year()))")
        }
        if book.source == .recommendation {
            lines.append("Llegó como recomendación")
        }
        return lines
    }

    private func deleteBook() {
        dismiss()
        // Se borra cuando la pantalla ya se ha cerrado: si se borra antes,
        // la animación de salida intentaría pintar un modelo eliminado.
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            modelContext.delete(book)
            try? modelContext.save()
        }
    }
}

/// Bloque con un rótulo pequeño encima, sin cajas ni separadores.
private struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text(title)
                .overlineStyle()
                .accessibilityAddTraits(.isHeader)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Leído") {
    NavigationStack {
        BookDetailView(book: SampleData.previewBook(titled: "Cien años de soledad"))
    }
    .modelContainer(SampleData.previewContainer)
}

#Preview("Leyendo · Oscuro") {
    NavigationStack {
        BookDetailView(book: SampleData.previewBook(titled: "Stoner"))
    }
    .modelContainer(SampleData.previewContainer)
    .preferredColorScheme(.dark)
}
