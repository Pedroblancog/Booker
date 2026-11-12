// Dibuja el icono de Booker (1024×1024) en sus variantes clara, oscura y tintada.
// Uso (desde la raíz del proyecto):
//   swift tools/RenderIcon.swift Booker/Resources/Assets.xcassets/AppIcon.appiconset
import AppKit
import SwiftUI

struct Palette {
    let background: Color
    let cover: Color
    let ink: Color
    let shadow: Double
}

struct IconView: View {
    let palette: Palette
    let size: CGFloat = 1024

    var body: some View {
        ZStack {
            palette.background

            // Luz cálida muy suave desde arriba, como en las pantallas de la app.
            RadialGradient(colors: [.white.opacity(0.10), .clear], center: .top, startRadius: 0, endRadius: size * 0.9)

            cover
                .frame(width: size * 0.54, height: size * 0.76)
                // Sin agrupar, la sombra se aplicaría también a la "B" dentro de la portada.
                .compositingGroup()
                .shadow(color: .black.opacity(palette.shadow * 0.4), radius: size * 0.006, y: size * 0.004)
                .shadow(color: .black.opacity(palette.shadow), radius: size * 0.05, y: size * 0.04)
                .offset(y: -size * 0.01)
        }
        .frame(width: size, height: size)
    }

    private var cover: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.018, style: .continuous)
        return ZStack(alignment: .topLeading) {
            palette.cover
            LinearGradient(colors: [.white.opacity(0.12), .clear, .black.opacity(0.18)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            // Lomo.
            LinearGradient(colors: [.black.opacity(0.28), .black.opacity(0.04), .clear],
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: size * 0.035)

            VStack(alignment: .leading, spacing: size * 0.028) {
                Rectangle()
                    .fill(palette.ink.opacity(0.55))
                    .frame(width: size * 0.06, height: size * 0.004)
                Text("B")
                    .font(.system(size: size * 0.32, weight: .regular, design: .serif))
                    .foregroundStyle(palette.ink)
            }
            .padding(.leading, size * 0.075)
            .padding(.top, size * 0.075)
        }
        .clipShape(shape)
    }
}

@MainActor
func render(_ palette: Palette, to url: URL) throws {
    let renderer = ImageRenderer(content: IconView(palette: palette))
    renderer.scale = 1
    guard let cgImage = renderer.cgImage else { throw CocoaError(.fileWriteUnknown) }
    let rep = NSBitmapImageRep(cgImage: cgImage)
    guard let png = rep.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
    try png.write(to: url)
    print("✓", url.lastPathComponent, cgImage.width, "×", cgImage.height)
}

func hex(_ value: UInt32) -> Color {
    Color(.sRGB, red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255,
          blue: Double(value & 0xFF) / 255)
}

let output = URL(fileURLWithPath: CommandLine.arguments[1])
MainActor.assumeIsolated {
    do {
        try render(Palette(background: hex(0xF7F4EE), cover: hex(0x7A2E2A), ink: hex(0xF7F2EA), shadow: 0.22),
                   to: output.appending(path: "icon-light.png"))
        try render(Palette(background: hex(0x131211), cover: hex(0x8C3B2E), ink: hex(0xF7F2EA), shadow: 0.6),
                   to: output.appending(path: "icon-dark.png"))
        // Tintada: escala de grises sobre negro; iOS aplica el color que elija el usuario.
        try render(Palette(background: .black, cover: hex(0x9A9A9A), ink: hex(0x1A1A1A), shadow: 0.5),
                   to: output.appending(path: "icon-tinted.png"))
    } catch {
        print("Error:", error)
        exit(1)
    }
}
