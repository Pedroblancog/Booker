import SwiftUI

/// Las portadas se hunden un poco al pulsarlas, con un muelle.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(DS.Motion.snappy, value: configuration.isPressed)
    }
}
