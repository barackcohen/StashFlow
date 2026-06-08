import SwiftUI
import SwiftData
import StockTrackerCore

@main
struct StockTrackerApp: App {
    // Inject our shared SwiftData container configured in StorageManager
    let container = StorageManager.shared.modelContainer
    
    var body: some Scene {
        WindowGroup {
            DashboardView()
                .preferredColorScheme(.dark) // Lock dark color scheme for neon glassmorphic look
        }
        .modelContainer(container)
    }
}
