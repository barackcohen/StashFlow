import XCTest
import SwiftData
@testable import StockTrackerCore

final class PortfolioTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    var calculator: PortfolioCalculator!
    
    @MainActor
    override func setUp() {
        super.setUp()
        container = StorageManager.makeInMemoryContainer()
        context = container.mainContext
        calculator = PortfolioCalculator()
    }
    
    override func tearDown() {
        context = nil
        container = nil
        calculator = nil
        super.tearDown()
    }
    
    @MainActor
    func testPortfolioAndPositionRelationship() throws {
        let portfolio = Portfolio(name: "Growth")
        context.insert(portfolio)
        
        let position = Position(ticker: "AAPL", shares: 15.5)
        context.insert(position)
        
        portfolio.positions.append(position)
        try context.save()
        
        XCTAssertEqual(portfolio.positions.count, 1)
        XCTAssertEqual(portfolio.positions.first?.ticker, "AAPL")
        XCTAssertEqual(portfolio.positions.first?.shares, 15.5)
        XCTAssertEqual(position.portfolio?.name, "Growth")
    }
    
    @MainActor
    func testPortfolioCalculations() {
        let portfolio = Portfolio(name: "Tech")
        context.insert(portfolio)
        
        let aapl = Position(ticker: "AAPL", shares: 10)
        let tsla = Position(ticker: "TSLA", shares: 5)
        
        portfolio.positions.append(aapl)
        portfolio.positions.append(tsla)
        
        let prices = ["AAPL": 150.0, "TSLA": 200.0]
        
        let total = calculator.calculateTotal(for: portfolio, prices: prices)
        XCTAssertEqual(total, 2500.0) // 10*150 + 5*200
        
        let allocations = calculator.calculateAllocations(for: portfolio, prices: prices)
        XCTAssertEqual(allocations["AAPL"], 60.0) // 1500 / 2500 * 100
        XCTAssertEqual(allocations["TSLA"], 40.0) // 1000 / 2500 * 100
    }
    
    @MainActor
    func testWeighted24hPerformance() {
        let portfolio = Portfolio(name: "Performance Test")
        context.insert(portfolio)
        
        let aapl = Position(ticker: "AAPL", shares: 10) // Price 150, change 2% -> Value 1500
        let tsla = Position(ticker: "TSLA", shares: 5)  // Price 200, change -1% -> Value 1000
        
        portfolio.positions.append(aapl)
        portfolio.positions.append(tsla)
        
        let prices: [String: (price: Double, change24h: Double)] = [
            "AAPL": (150.0, 2.0),
            "TSLA": (200.0, -1.0)
        ]
        
        let weightedChange = calculator.calculateWeighted24hChange(for: portfolio, prices: prices)
        // Weighted change = (1500 * 2.0 + 1000 * -1.0) / 2500 = (3000 - 1000) / 2500 = 2000 / 2500 = 0.8%
        XCTAssertEqual(weightedChange, 0.8, accuracy: 0.001)
    }
    
    @MainActor
    func testCustomAssetCalculations() {
        let portfolio = Portfolio(name: "Mixed")
        context.insert(portfolio)
        
        let aapl = Position(ticker: "AAPL", shares: 10) // Price 150 -> Value 1500 USD
        let apartment = Position(ticker: "Apartment", shares: 1000000, isCustomAsset: true, customCurrency: "ILS") // 1M ILS. Rate USDILS=X = 4.0 -> Value 250000 USD
        
        portfolio.positions.append(aapl)
        portfolio.positions.append(apartment)
        
        let prices = [
            "AAPL": 150.0,
            "USDILS=X": 4.0
        ]
        
        let total = calculator.calculateTotal(for: portfolio, prices: prices)
        XCTAssertEqual(total, 251500.0) // 1500 + 250000
        
        let allocations = calculator.calculateAllocations(for: portfolio, prices: prices)
        XCTAssertEqual(allocations["AAPL"], (1500.0 / 251500.0) * 100.0, accuracy: 0.001)
        XCTAssertEqual(allocations["Apartment"], (250000.0 / 251500.0) * 100.0, accuracy: 0.001)
        
        // 24h change test:
        // AAPL: 150 USD, change 2% -> Value 1500
        // Apartment: 250000 USD, change 0% (custom asset) -> Value 250000
        let prices24h: [String: (price: Double, change24h: Double)] = [
            "AAPL": (150.0, 2.0),
            "USDILS=X": (4.0, 1.0)
        ]
        
        let weightedChange = calculator.calculateWeighted24hChange(for: portfolio, prices: prices24h)
        // (1500 * 2.0 + 250000 * 0.0) / 251500 = 3000 / 251500 = 0.0119%
        XCTAssertEqual(weightedChange, (3000.0 / 251500.0), accuracy: 0.001)
    }
}
