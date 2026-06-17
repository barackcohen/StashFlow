import Foundation

public protocol StockPriceServiceProtocol: Sendable {
    func fetchPrice(for ticker: String) async throws -> (price: Double, change24h: Double)
    func fetchPrices(for tickers: [String]) async -> [String: (price: Double, change24h: Double)]
    func searchSymbols(query: String) async throws -> [SymbolSearchResult]
}

public struct SymbolSearchResult: Codable, Identifiable, Sendable {
    public var id: String { symbol }
    public let symbol: String
    public let shortname: String?
    public let longname: String?
    public let exchange: String
    public let exchDisp: String?
    public let typeDisp: String?
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
        
        // Use Yahoo Finance public chart API with pre/post-market data enabled
        let urlString = "https://query1.finance.yahoo.com/v8/finance/chart/\(cleanTicker)?includePrePost=true"
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
        
        // Try to get the latest pre/post-market price from indicators, falling back to regularMarketPrice
        var price = resultItem.meta.regularMarketPrice
        if let quote = resultItem.indicators?.quote?.first,
           let closes = quote.close {
            if let lastClose = closes.last(where: { $0 != nil }), let finalPrice = lastClose {
                price = finalPrice
            }
        }
        
        var prevClose = resultItem.meta.chartPreviousClose ?? price
        
        // If the latest data point falls within the pre-market trading period,
        // we use yesterday's regular session close (previousClose or regularMarketPrice)
        // to show the pre-market change alone, rather than combining it with yesterday's change.
        if let lastTimestamp = resultItem.timestamp?.last,
           let periods = resultItem.meta.currentTradingPeriod,
           lastTimestamp >= periods.pre.start && lastTimestamp <= periods.pre.end {
            prevClose = resultItem.meta.regularMarketPrice != 0 ? resultItem.meta.regularMarketPrice : prevClose
        }
        
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
    
    public func searchSymbols(query: String) async throws -> [SymbolSearchResult] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else { return [] }
        
        guard let encodedQuery = cleanQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://query1.finance.yahoo.com/v1/finance/search?q=\(encodedQuery)") else {
            throw NSError(domain: "StockPriceService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid query"])
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "StockPriceService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to search symbols"])
        }
        
        let decoder = JSONDecoder()
        let result = try decoder.decode(YahooSearchResponse.self, from: data)
        
        // Filter out results that are not stocks, ETFs, or index instruments (e.g. news items)
        return result.quotes.map { quote in
            SymbolSearchResult(
                symbol: quote.symbol,
                shortname: quote.shortname,
                longname: quote.longname,
                exchange: quote.exchange,
                exchDisp: quote.exchDisp,
                typeDisp: quote.typeDisp
            )
        }
    }
}

// MARK: - Yahoo Search Response Mapping Structs

private struct YahooSearchResponse: Codable {
    struct Quote: Codable {
        let symbol: String
        let shortname: String?
        let longname: String?
        let exchange: String
        let exchDisp: String?
        let typeDisp: String?
    }
    let quotes: [Quote]
}

// MARK: - Yahoo Finance JSON Mapping Structs

private struct TradingPeriod: Codable {
    let start: Int
    let end: Int
}

private struct CurrentTradingPeriod: Codable {
    let pre: TradingPeriod
    let regular: TradingPeriod
    let post: TradingPeriod
}

private struct YahooFinanceResult: Codable {
    struct Chart: Codable {
        struct ResultItem: Codable {
            struct Meta: Codable {
                let symbol: String
                let regularMarketPrice: Double
                let chartPreviousClose: Double?
                let previousClose: Double?
                let currentTradingPeriod: CurrentTradingPeriod?
            }
            struct Indicators: Codable {
                struct Quote: Codable {
                    let close: [Double?]?
                }
                let quote: [Quote]?
            }
            let meta: Meta
            let indicators: Indicators?
            let timestamp: [Int]?
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
