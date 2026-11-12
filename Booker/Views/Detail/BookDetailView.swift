import SwiftData
import SwiftUI

/// Detalle de un libro: el libro se abre y muestra su primera página; debajo,
/// puntuación (solo leídos), estado, notas y acciones discretas de editar y eliminar.
struct BookDetailView: View {
    @Bindable var book: Book
    var transitionNamespace: Namespace.ID?
    /// Origen de la transición zoom (cuadrícula, "Leyendo ahora"…).
    var transitionID: String?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dominantColorExtractor) private var colorExtractor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var isEditing = false
    @State private var isConfirmingDelete = false
    @State private var saveCount = 0
    @State private var isBookOpen = false
    @FocusState private var isEditingNotes: Bool

    /// Con texto de accesibilidad el título no cabría en una página de libro:
    /// se usa la portada con el título debajo.
    private var usesOpeningBook: Bool { !dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xxl) {
                hero
                statusSection
                notesSection
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
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Listo") { isEditingNotes = false }
            }
        }
        .tint(DS.Colors.inkPrimary)
        .zoomTransitionDestination(id: transitionID ?? book.id.uuidString, in: transitionNamespace)
        .sensoryFeedback(.impact(weight: .light), trigger: isBookOpen)
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
            Text("Se borrarán también tu puntuación y tus notas.")
        }
        .sensoryFeedback(.success, trigger: saveCount)
        .onChange(of: isEditingNotes) { _, isFocused in
            if !isFocused { try? modelContext.save() }
        }
        .task {
            await colorExtractor.assignDominantColorIfNeeded(to: book)
        }
        .task {
            // Sin movimiento, el libro aparece ya abierto. Si no, se abre cuando
            // ha terminado de llegar la portada desde la cuadrícula.
            if reduceMotion {
                isBookOpen = true
                return
            }
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.spring(duration: 0.9, bounce: 0.12)) { isBookOpen = true }
        }
    }

    // MARK: - Secciones

    @ViewBuilder
    private var hero: some View {
        if usesOpeningBook {
            openingBookHero
        } else {
            coverHero
        }
    }

    /// El libro que se abre. Tocarlo lo cierra y lo vuelve a abrir.
    private var openingBookHero: some View {
        VStack(spacing: DS.Spacing.l) {
            GeometryReader { proxy in
                OpeningBookView(book: book, isOpen: isBookOpen, pageWidth: proxy.size.width * Self.pageFraction) {
                    FirstPage(book: book)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(reduceMotion ? DS.Motion.reduced : .spring(duration: 0.8, bounce: 0.12)) {
                        isBookOpen.toggle()
                    }
                }
            }
            // Alto de una página para el ancho disponible.
            .aspectRatio(1 / (Self.pageFraction / DS.Layout.coverAspectRatio), contentMode: .fit)
            .padding(.vertical, DS.Spacing.s)
            .accessibilityAction(named: isBookOpen ? "Cerrar el libro" : "Abrir el libro") {
                isBookOpen.toggle()
            }

            if book.status == .read {
                StarRatingView(rating: book.rating) { book.setRating($0) }
                    .transition(.appear(reduceMotion: reduceMotion))
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Cada página ocupa algo menos de la mitad del ancho: abierto, el pliego cabe entero.
    private static let pageFraction: CGFloat = 0.48

    /// Diseño para texto de accesibilidad: portada y, debajo, título y autor.
    private var coverHero: some View {
        VStack(spacing: DS.Spacing.l) {
            BookCoverView(book: book)
                .containerRelativeFrame(.horizontal) { length, _ in length * 0.56 }
                .padding(.bottom, DS.Spacing.s)

            VStack(spacing: DS.Spacing.xs) {
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
            }

            if book.status == .read {
                StarRatingView(rating: book.rating) { book.setRating($0) }
                    .transition(.appear(reduceMotion: reduceMotion))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var statusSection: some View {
        DetailSection("Estado") {
            UnderlineSegmentedControl(items: BookStatus.allCases, selection: $book.status) { $0.title }
        }
    }

    /// Las notas se presentan como una cita de revista: cursiva y un filete dorado.
    private var notesSection: some View {
        DetailSection("Notas") {
            HStack(alignment: .top, spacing: DS.Spacing.m) {
                Rectangle()
                    .fill(DS.Colors.accent)
                    .frame(width: 1.5)
                    .accessibilityHidden(true)

                TextField("Escribe lo que no quieras olvidar…", text: notesBinding, axis: .vertical)
                    .font(DS.Typography.reason)
                    .foregroundStyle(DS.Colors.inkPrimary)
                    .lineSpacing(4)
                    .focused($isEditingNotes)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
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
