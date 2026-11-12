import SwiftUI

/// Pestañas principales.
struct RootView: View {
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
    }
}

#Preview {
    RootView()
        .modelContainer(SampleData.previewContainer)
}
