import Foundation

public protocol StockPriceServiceProtocol: Sendable {
    func fetchPrice(for ticker: String) async throws -> (price: Double, change24h: Double)
    func fetchPrices(for tickers: [String]) async -> [String: (price: Double, change24h: Double)]
}

public final class StockPriceService: StockPriceServiceProtocol, @unchecked Sendable {
    private let session: URLSession
    
    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    public func fetchPrice(for ticker: String) async throws -> (price: Double, change24h: Double) {
        let cleanTicker = ticker.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTicker.isEmpty else {
            throw NSError(domain: "StockPriceService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Ticker cannot be empty"])
        }
        
        // Use Yahoo Finance public chart API
        let urlString = "https://query1.finance.yahoo.com/v8/finance/chart/\(cleanTicker)"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "StockPriceService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL for ticker: \(cleanTicker)"])
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "StockPriceService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "StockPriceService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch data, server returned status \(httpResponse.statusCode)"])
        }
        
        let decoder = JSONDecoder()
        let result = try decoder.decode(YahooFinanceResult.self, from: data)
        
        guard let resultItem = result.chart.result?.first else {
            if let err = result.chart.error {
                throw NSError(domain: "StockPriceService", code: 500, userInfo: [NSLocalizedDescriptionKey: err.description])
            }
            throw NSError(domain: "StockPriceService", code: 404, userInfo: [NSLocalizedDescriptionKey: "No data found for \(cleanTicker)"])
        }
        
        let price = resultItem.meta.regularMarketPrice
        let prevClose = resultItem.meta.chartPreviousClose ?? price
        let change24h = prevClose != 0 ? ((price - prevClose) / prevClose) * 100.0 : 0.0
        
        return (price, change24h)
    }
    
    public func fetchPrices(for tickers: [String]) async -> [String: (price: Double, change24h: Double)] {
        var results: [String: (price: Double, change24h: Double)] = [:]
        
        // Run concurrent fetches using TaskGroup
        await withTaskGroup(of: (String, (price: Double, change24h: Double)?).self) { group in
            for ticker in tickers {
                group.addTask {
                    do {
                        let res = try await self.fetchPrice(for: ticker)
                        return (ticker, res)
                    } catch {
                        print("Error fetching price for \(ticker): \(error.localizedDescription)")
                        return (ticker, nil)
                    }
                }
            }
            
            for await (ticker, value) in group {
                if let value = value {
                    results[ticker] = value
                }
            }
        }
        
        return results
    }
}

// MARK: - Yahoo Finance JSON Mapping Structs

private struct YahooFinanceResult: Codable {
    struct Chart: Codable {
        struct ResultItem: Codable {
            struct Meta: Codable {
                let symbol: String
                let regularMarketPrice: Double
                let chartPreviousClose: Double?
            }
            let meta: Meta
        }
        struct ErrorItem: Codable {
            let code: String
            let description: String
        }
        let result: [ResultItem]?
        let error: ErrorItem?
    }
    let chart: Chart
}
