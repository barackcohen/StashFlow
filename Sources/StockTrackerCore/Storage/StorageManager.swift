import Foundation
import SwiftData

public final class StorageManager: @unchecked Sendable {
    public static let shared = StorageManager()
    
    public let modelContainer: ModelContainer
    
    private init() {
        let schema = Schema([
            Portfolio.self,
            Position.self,
            StockPrice.self
        ])
        
        // App Group identifier for sharing data with the Home Screen Widget
        let appGroupId = "group.com.barackcohen.myportfolios"
        let modelConfiguration: ModelConfiguration
        
        if let sharedContainerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) {
            let storeURL = sharedContainerURL.appendingPathComponent("StockTracker.sqlite")
            modelConfiguration = ModelConfiguration(schema: schema, url: storeURL)
        } else {
            // Fallback for local testing when app group is not available (e.g. running unit tests)
            modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        }
        
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Safe fallback to memory-only database on failure to ensure app never crashes on initialization
            do {
                let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                modelContainer = try ModelContainer(for: schema, configurations: [fallbackConfig])
            } catch {
                fatalError("Fatal: Could not initialize SwiftData ModelContainer: \(error.localizedDescription)")
            }
        }
    }
    
    /// Generates an in-memory ModelContainer specifically for unit testing purposes.
    public static func makeInMemoryContainer() -> ModelContainer {
        let schema = Schema([
            Portfolio.self,
            Position.self,
            StockPrice.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create in-memory ModelContainer: \(error.localizedDescription)")
        }
    }
}
