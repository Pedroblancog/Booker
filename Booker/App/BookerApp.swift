import SwiftData
import SwiftUI

@main
struct BookerApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Book.self)
        } catch {
            fatalError("No se pudo abrir la base de datos: \(error)")
        }

        #if DEBUG
        // Mientras no exista el buscador (Fase 3), la app arranca con datos de prueba.
        SampleData.seedIfEmpty(container.mainContext)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
