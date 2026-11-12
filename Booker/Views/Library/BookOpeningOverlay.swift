import SwiftUI

/// La apertura de un libro desde la biblioteca: la portada sale de su sitio
/// hasta el centro, la tapa se abre sobre el lomo y la vista se mete dentro
/// de la primera página, que crece hasta ocupar la pantalla y se funde con
/// la ficha del libro.
///
/// La ficha se coloca debajo (sin animación) cuando la página ya cubre toda
/// la pantalla; después esta capa se desvanece y queda la ficha.
struct BookOpeningOverlay: View {
    let book: Book
    /// Dónde estaba la portada, en coordenadas globales.
    let sourceFrame: CGRect
    /// Momento de colocar la ficha debajo.
    let onReveal: () -> Void
    let onFinish: () -> Void

    private enum Phase: Int, Comparable {
        case lifting, centered, open, diving, done

        static func < (a: Phase, b: Phase) -> Bool { a.rawValue < b.rawValue }
    }

    @State private var phase = Phase.lifting

    var body: some View {
        GeometryReader { proxy in
            let container = proxy.frame(in: .global)
            let aspect = BookCoverView.aspectRatio(of: book)
            // Abierto, el pliego (dos páginas) ocupa casi todo el ancho.
            let pageWidth = min(container.width * 0.46, container.height * 0.42 * aspect)
            let pageHeight = pageWidth / aspect
            let start = sourceFrame.offsetBy(dx: -container.minX, dy: -container.minY)

            ZStack {
                TintedBackground(colorHex: book.dominantColorHex)
                    .opacity(phase == .lifting ? 0 : 1)

                OpeningBookView(book: book, isOpen: phase >= .open, pageWidth: pageWidth) {
                    // Al meterse en la página, las letras se apartan.
                    FirstPage(book: book)
                        .opacity(phase >= .diving ? 0 : 1)
                }
                // Al entrar, el zoom se centra en la primera página (la de la
                // derecha, cuyo centro es el borde derecho de este marco).
                .scaleEffect(scale(start: start, page: CGSize(width: pageWidth, height: pageHeight), in: container.size),
                             anchor: phase >= .diving ? UnitPoint(x: 1, y: 0.5) : .center)
                .position(position(start: start, pageWidth: pageWidth, in: container.size))
            }
            .opacity(phase == .done ? 0 : 1)
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .sensoryFeedback(.impact(weight: .light), trigger: phase) { _, new in new == .open }
        .accessibilityHidden(true)
        .task { await play() }
    }

    private func scale(start: CGRect, page: CGSize, in screen: CGSize) -> CGFloat {
        guard page.width > 0, page.height > 0 else { return 1 }
        switch phase {
        case .lifting: return start.width / page.width
        case .centered, .open: return 1
        // La página crece hasta cubrir toda la pantalla.
        case .diving, .done: return max(screen.width / page.width, screen.height / page.height) * 1.08
        }
    }

    private func position(start: CGRect, pageWidth: CGFloat, in screen: CGSize) -> CGPoint {
        switch phase {
        case .lifting:
            return CGPoint(x: start.midX, y: start.midY)
        case .centered, .open:
            // Abierto, `OpeningBookView` ya se desplaza para centrar el pliego.
            return CGPoint(x: screen.width / 2, y: screen.height * 0.42)
        case .diving, .done:
            // La primera página va al centro de la pantalla mientras crece.
            return CGPoint(x: screen.width / 2 - pageWidth / 2, y: screen.height / 2)
        }
    }

    /// Un solo movimiento: cada fase empieza antes de que acabe la anterior,
    /// así que la portada sube mientras empieza a abrirse, y el zoom arranca
    /// con la tapa aún girando. Cada fase anima propiedades distintas
    /// (posición, ángulo de la tapa, escala), así que se suman sin saltos.
    private func play() async {
        // Un fotograma en la posición de partida, para que la animación salga de ahí.
        try? await Task.sleep(for: .milliseconds(20))
        withAnimation(.spring(duration: 0.5, bounce: 0.1)) { phase = .centered }
        try? await Task.sleep(for: .milliseconds(170))
        withAnimation(.spring(duration: 0.85, bounce: 0)) { phase = .open }
        try? await Task.sleep(for: .milliseconds(400))
        // El zoom entra suave mientras la tapa termina de abrirse y acelera
        // hacia la página.
        withAnimation(.timingCurve(0.45, 0, 0.2, 1, duration: 0.85)) { phase = .diving }
        try? await Task.sleep(for: .milliseconds(480))
        // La página ya cubre la pantalla: la ficha aparece mientras el zoom sigue.
        onReveal()
        withAnimation(.easeOut(duration: 0.4)) { phase = .done }
        try? await Task.sleep(for: .milliseconds(420))
        onFinish()
    }
}

// MARK: - Posición de las portadas

/// Dónde está cada portada en pantalla, para que la apertura salga de ahí.
/// Es una clase y no un estado: se actualiza al desplazar sin redibujar nada.
final class CoverFrames {
    private var frames: [String: CGRect] = [:]

    subscript(id: String) -> CGRect? {
        get { frames[id] }
        set { frames[id] = newValue }
    }
}

extension View {
    /// Apunta en `frames` la posición global de esta vista.
    func recordsCoverFrame(id: String, in frames: CoverFrames) -> some View {
        onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frames[id] = $0 }
    }
}
