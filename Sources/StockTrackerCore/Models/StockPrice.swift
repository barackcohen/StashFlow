import Foundation
import SwiftData

@Model
public final class StockPrice {
    @Attribute(.unique) public var ticker: String
    public var price: Double
    public var change24h: Double
    public var lastUpdated: Date
    
    public init(ticker: String, price: Double, change24h: Double = 0.0, lastUpdated: Date = Date()) {
        self.ticker = ticker.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.price = price
        self.change24h = change24h
        self.lastUpdated = lastUpdated
    }
}
