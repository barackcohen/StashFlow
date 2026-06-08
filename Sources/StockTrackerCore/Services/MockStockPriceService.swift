import Foundation

public final class MockStockPriceService: StockPriceServiceProtocol, @unchecked Sendable {
    public var mockPrices: [String: (price: Double, change24h: Double)] = [
        "AAPL": (175.50, 1.2),
        "TSLA": (180.20, -2.4),
        "MSFT": (420.10, 0.85),
        "GOOGL": (150.30, -0.4),
        "AMZN": (185.00, 2.1),
        "USDEUR=X": (0.92, 0.1),
        "USDGBP=X": (0.78, -0.05),
        "USDCAD=X": (1.36, 0.15),
        "USDILS=X": (3.72, -0.2),
        "USDJPY=X": (156.40, 0.4),
        "USDAUD=X": (1.50, 0.05),
        "USDCHF=X": (0.89, -0.1)
    ]
    
    public init() {}
    
    public func fetchPrice(for ticker: String) async throws -> (price: Double, change24h: Double) {
        let cleanTicker = ticker.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let mock = mockPrices[cleanTicker] {
            return mock
        }
        // If ticker is not in our mock dict, return a default mock price based on the hash of the string
        let price = Double(abs(cleanTicker.hashValue) % 300) + 10.0
        let change = Double(cleanTicker.hashValue % 100) / 20.0
        return (price, change)
    }
    
    public func fetchPrices(for tickers: [String]) async -> [String: (price: Double, change24h: Double)] {
        var results: [String: (price: Double, change24h: Double)] = [:]
        for ticker in tickers {
            if let price = try? await fetchPrice(for: ticker) {
                results[ticker] = price
            }
        }
        return results
    }
}
