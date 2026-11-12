import SwiftUI

// La transición "zoom" de portada a detalle solo existe desde iOS 18
// (`matchedTransitionSource` y `navigationTransition(.zoom)`).
// En iOS 17 se usa la transición de navegación estándar.

extension View {
    /// Marca la vista como origen de la transición zoom.
    @ViewBuilder
    func zoomTransitionSource(id: some Hashable, in namespace: Namespace.ID?) -> some View {
        if #available(iOS 18.0, *), let namespace {
            matchedTransitionSource(id: id, in: namespace) { source in
                source.clipShape(RoundedRectangle(cornerRadius: DS.Radius.cover, style: .continuous))
            }
        } else {
            self
        }
    }

    /// Aplica la transición zoom a la pantalla de destino.
    @ViewBuilder
    func zoomTransitionDestination(id: some Hashable, in namespace: Namespace.ID?) -> some View {
        if #available(iOS 18.0, *), let namespace {
            navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}

/// Las portadas se hunden un poco al pulsarlas, con un muelle.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(DS.Motion.snappy, value: configuration.isPressed)
    }
}
