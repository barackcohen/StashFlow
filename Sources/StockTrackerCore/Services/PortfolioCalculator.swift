import Foundation

public final class PortfolioCalculator {
    
    public init() {}
    
    /// Calculates the total value of a single portfolio.
    public func calculateTotal(for portfolio: Portfolio, prices: [String: Double]) -> Double {
        var total = 0.0
        for position in portfolio.positions {
            let price = prices[position.ticker.uppercased()] ?? 0.0
            total += position.shares * price
        }
        return total
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
            let price = prices[position.ticker.uppercased()] ?? 0.0
            let value = position.shares * price
            allocations[position.ticker] = (value / totalVal) * 100.0
        }
        return allocations
    }
    
    /// Calculates the overall 24h weighted percentage change of a portfolio based on individual stock 24h performance
    public func calculateWeighted24hChange(for portfolio: Portfolio, prices: [String: (price: Double, change24h: Double)]) -> Double {
        let totalVal = portfolio.positions.reduce(0.0) { sum, pos in
            let price = prices[pos.ticker.uppercased()]?.price ?? 0.0
            return sum + (pos.shares * price)
        }
        
        guard totalVal > 0 else { return 0.0 }
        
        var weightedSum = 0.0
        for pos in portfolio.positions {
            let priceInfo = prices[pos.ticker.uppercased()]
            let price = priceInfo?.price ?? 0.0
            let change = priceInfo?.change24h ?? 0.0
            let value = pos.shares * price
            weightedSum += value * change
        }
        
        return weightedSum / totalVal
    }
}
