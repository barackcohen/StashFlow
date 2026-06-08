import WidgetKit
import SwiftUI
import SwiftData
import StockTrackerCore
import Foundation

struct PortfolioEntry: TimelineEntry {
    let date: Date
    let totalValue: Double
    let dayChangePercent: Double
    let lastUpdated: Date
}

struct PortfolioProvider: TimelineProvider {
    typealias Entry = PortfolioEntry
    
    private let calculator = PortfolioCalculator()
    
    func placeholder(in context: Context) -> PortfolioEntry {
        PortfolioEntry(date: Date(), totalValue: 124580.20, dayChangePercent: 1.48, lastUpdated: Date())
    }
    
    func getSnapshot(in context: Context, completion: @escaping (PortfolioEntry) -> Void) {
        let entry = loadCurrentData()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<PortfolioEntry>) -> Void) {
        let entry = loadCurrentData()
        // Schedule standard background re-checks every 30 minutes. 
        // Can be forced to reload on-demand using the widget button.
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func loadCurrentData() -> PortfolioEntry {
        let context = ModelContext(StorageManager.shared.modelContainer)
        
        let portfoliosDescriptor = FetchDescriptor<Portfolio>()
        let portfolios = (try? context.fetch(portfoliosDescriptor)) ?? []
        
        let pricesDescriptor = FetchDescriptor<StockPrice>()
        let cachedPrices = (try? context.fetch(pricesDescriptor)) ?? []
        
        var priceMap: [String: Double] = [:]
        var priceInfoMap: [String: (price: Double, change24h: Double)] = [:]
        for price in cachedPrices {
            priceMap[price.ticker] = price.price
            priceInfoMap[price.ticker] = (price.price, price.change24h)
        }
        
        let total = calculator.calculateGrandTotal(portfolios: portfolios, prices: priceMap)
        
        var weightedSum = 0.0
        for portfolio in portfolios {
            let pTotal = calculator.calculateTotal(for: portfolio, prices: priceMap)
            let pChange = calculator.calculateWeighted24hChange(for: portfolio, prices: priceInfoMap)
            weightedSum += pTotal * pChange
        }
        let totalChange = total > 0 ? (weightedSum / total) : 0.0
        let latestUpdate = cachedPrices.map { $0.lastUpdated }.max() ?? Date()
        
        return PortfolioEntry(date: Date(), totalValue: total, dayChangePercent: totalChange, lastUpdated: latestUpdate)
    }
}

struct PortfolioWidgetEntryView: View {
    var entry: PortfolioProvider.Entry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Stock Total")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                Spacer()
                
                // Interactive Refresh Button in widget (iOS 17+)
                Button(intent: RefreshPricesIntent()) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            Text(formatCurrency(entry.totalValue))
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .minimumScaleFactor(0.8)
            
            HStack(spacing: 3) {
                Image(systemName: entry.dayChangePercent >= 0 ? "arrow.up.right" : "arrow.down.left")
                    .font(.system(size: 8, weight: .bold))
                Text(String(format: "%.2f%%", entry.dayChangePercent))
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(entry.dayChangePercent >= 0 ? .green : .red)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background((entry.dayChangePercent >= 0 ? Color.green : Color.red).opacity(0.15))
            .clipShape(Capsule())
            
            Spacer()
            
            Text("Updated: \(entry.lastUpdated, style: .time)")
                .font(.system(size: 8))
                .foregroundColor(.gray)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            ZStack {
                Color.black
                RadialGradient(
                    colors: [Color(hex: "#8A2BE2").opacity(0.25), Color.black],
                    center: .bottomTrailing,
                    startRadius: 5,
                    endRadius: 90
                )
            }
        )
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}

@main
struct PortfolioWidget: Widget {
    let kind: String = "PortfolioWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PortfolioProvider()) { entry in
            PortfolioWidgetEntryView(entry: entry)
                .containerBackground(.fill.ternary, for: .widget)
        }
        .configurationDisplayName("Portfolio Tracker")
        .description("Track your total investments at a glance.")
        .supportedFamilies([.systemSmall])
    }
}
