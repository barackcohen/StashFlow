import Foundation

public final class PortfolioCalculator {
    
    public init() {}
    
    /// Calculates the total value of a single portfolio.
    public func calculateTotal(for portfolio: Portfolio, prices: [String: Double]) -> Double {
        var total = 0.0
        for position in portfolio.positions {
            total += calculatePositionValue(position, prices: prices)
        }
        return total
    }
    
    /// Calculates the value of a single position in USD.
    public func calculatePositionValue(_ position: Position, prices: [String: Double]) -> Double {
        if position.isCustomAsset {
            let currency = position.customCurrency ?? "USD"
            if currency.uppercased() == "USD" {
                return position.shares
            } else {
                let rateTicker = AppGroupSettings.shared.getExchangeRateTicker(for: currency)
                let rate = prices[rateTicker] ?? 1.0
                return position.shares / (rate > 0 ? rate : 1.0)
            }
        } else {
            let price = prices[position.ticker.uppercased()] ?? 0.0
            return position.shares * price
        }
    }
    
    /// Calculates the grand total across all portfolios.
    public func calculateGrandTotal(portfolios: [Portfolio], prices: [String: Double]) -> Double {
        return portfolios.reduce(0.0) { sum, portfolio in
            sum + calculateTotal(for: portfolio, prices: prices)
        }
    }
    
    /// Calculates the weighted allocations for each position in a portfolio, returning a dictionary of [Ticker: Percentage]
    public func calculateAllocations(for portfolio: Portfolio, prices: [String: Double]) -> [String: Double] {
        let totalVal = calculateTotal(for: portfolio, prices: prices)
        guard totalVal > 0 else { return [:] }
        
        var allocations: [String: Double] = [:]
        for position in portfolio.positions {
            let value = calculatePositionValue(position, prices: prices)
            allocations[position.ticker] = (value / totalVal) * 100.0
        }
        return allocations
    }
    
    /// Calculates the overall 24h weighted percentage change of a portfolio based on individual stock 24h performance
    public func calculateWeighted24hChange(for portfolio: Portfolio, prices: [String: (price: Double, change24h: Double)]) -> Double {
        let priceMap = prices.mapValues { $0.price }
        let totalVal = portfolio.positions.reduce(0.0) { sum, pos in
            sum + calculatePositionValue(pos, prices: priceMap)
        }
        
        guard totalVal > 0 else { return 0.0 }
        
        var weightedSum = 0.0
        for pos in portfolio.positions {
            let value = calculatePositionValue(pos, prices: priceMap)
            let change = pos.isCustomAsset ? 0.0 : (prices[pos.ticker.uppercased()]?.change24h ?? 0.0)
            weightedSum += value * change
        }
        
        return weightedSum / totalVal
    }
}
