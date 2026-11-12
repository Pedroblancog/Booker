import SwiftUI

/// Pestañas principales.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.coverImageProvider) private var coverProvider
    @Environment(\.dominantColorExtractor) private var colorExtractor

    var body: some View {
        TabView {
            LibraryView()
                .tabItem { Label("Biblioteca", systemImage: "books.vertical") }

            DiscoverView()
                .tabItem { Label("Descubrir", systemImage: "sparkles") }

            SearchView()
                .tabItem { Label("Buscar", systemImage: "magnifyingglass") }
        }
        .tint(DS.Colors.inkPrimary)
        .task {
            // Con la app ya en pantalla, en segundo plano: portadas más nítidas
            // para lo que ya estaba guardado. No durante los tests.
            guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
            try? await Task.sleep(for: .seconds(1.5))
            await CoverUpgrader(context: modelContext, covers: coverProvider, colors: colorExtractor).upgradeLibrary()
        }
    }
}

#Preview {
    RootView()
        .modelContainer(SampleData.previewContainer)
}
