import AppIntents
import WidgetKit
import SwiftData
import StockTrackerCore
import Foundation

public struct RefreshPricesIntent: AppIntent {
    public static var title: LocalizedStringResource = "Refresh Stock Prices"
    public static var description = IntentDescription("Fetches latest stock prices in the background and updates the widget.")
    
    public init() {}
    
    public func perform() async throws -> some IntentResult {
        // Create model context from shared database container
        let context = ModelContext(StorageManager.shared.modelContainer)
        
        // Retrieve all unique stock tickers currently tracked in the database
        let positionsDescriptor = FetchDescriptor<Position>()
        let positions = (try? context.fetch(positionsDescriptor)) ?? []
        let tickers = Array(Set(positions.map { $0.ticker }))
        
        if tickers.isEmpty {
            return .result()
        }
        
        // Perform concurrent API fetches
        let service = StockPriceService()
        let fetched = await service.fetchPrices(for: tickers)
        
        // Retrieve cached stock price records to update them
        let pricesDescriptor = FetchDescriptor<StockPrice>()
        let cachedPrices = (try? context.fetch(pricesDescriptor)) ?? []
        
        for (ticker, val) in fetched {
            if let existing = cachedPrices.first(where: { $0.ticker == ticker }) {
                existing.price = val.price
                existing.change24h = val.change24h
                existing.lastUpdated = Date()
            } else {
                let newPrice = StockPrice(ticker: ticker, price: val.price, change24h: val.change24h)
                context.insert(newPrice)
            }
        }
        
        try? context.save()
        
        // Refresh Widget UI immediately
        WidgetCenter.shared.reloadAllTimelines()
        
        return .result()
    }
}
