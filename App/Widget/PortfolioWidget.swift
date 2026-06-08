import WidgetKit
import SwiftUI
import SwiftData
import StockTrackerCore
import Foundation

struct WidgetPortfolioItem: Identifiable {
    let id: UUID
    let name: String
    let value: Double
    let change24h: Double
    let hexColor: String
}

struct PortfolioEntry: TimelineEntry {
    let date: Date
    let totalValue: Double
    let dayChangePercent: Double
    let lastUpdated: Date
    let portfolios: [WidgetPortfolioItem]
}

struct PortfolioProvider: TimelineProvider {
    typealias Entry = PortfolioEntry
    
    private let calculator = PortfolioCalculator()
    
    func placeholder(in context: Context) -> PortfolioEntry {
        PortfolioEntry(
            date: Date(),
            totalValue: 124580.20,
            dayChangePercent: 1.48,
            lastUpdated: Date(),
            portfolios: [
                WidgetPortfolioItem(id: UUID(), name: "Tech Portfolio", value: 84200.0, change24h: 1.34, hexColor: "#00F0FF"),
                WidgetPortfolioItem(id: UUID(), name: "Speculative", value: 40380.20, change24h: 1.81, hexColor: "#8A2BE2")
            ]
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (PortfolioEntry) -> Void) {
        let entry = loadCurrentData()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<PortfolioEntry>) -> Void) {
        let entry = loadCurrentData()
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
        var items: [WidgetPortfolioItem] = []
        for portfolio in portfolios {
            let pTotal = calculator.calculateTotal(for: portfolio, prices: priceMap)
            let pChange = calculator.calculateWeighted24hChange(for: portfolio, prices: priceInfoMap)
            weightedSum += pTotal * pChange
            
            items.append(WidgetPortfolioItem(
                id: portfolio.id,
                name: portfolio.name,
                value: pTotal,
                change24h: pChange,
                hexColor: portfolio.hexColor
            ))
        }
        
        // Sort portfolios by value descending
        items.sort(by: { $0.value > $1.value })
        
        let totalChange = total > 0 ? (weightedSum / total) : 0.0
        let latestUpdate = cachedPrices.map { $0.lastUpdated }.max() ?? Date()
        
        return PortfolioEntry(
            date: Date(),
            totalValue: total,
            dayChangePercent: totalChange,
            lastUpdated: latestUpdate,
            portfolios: items
        )
    }
}

struct PortfolioWidgetEntryView: View {
    var entry: PortfolioProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        ZStack {
            Color.black
            RadialGradient(
                colors: [Color(hex: "#8A2BE2").opacity(0.25), Color.black],
                center: .bottomTrailing,
                startRadius: 5,
                endRadius: 90
            )
            
            switch family {
            case .systemSmall:
                smallLayout
            case .systemMedium:
                mediumLayout
            default:
                smallLayout
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Small Layout
    
    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Stock Total")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                Spacer()
                
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
    }
    
    // MARK: - Medium Layout
    
    private var mediumLayout: some View {
        HStack(spacing: 16) {
            // Left Column (Total Balance summary)
            VStack(alignment: .leading, spacing: 6) {
                Text("Total Balance")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(formatCurrency(entry.totalValue))
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.7)
                
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
                
                HStack(spacing: 6) {
                    Button(intent: RefreshPricesIntent()) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 8, weight: .bold))
                            Text("Refresh")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    
                    Text("\(entry.lastUpdated, style: .time)")
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Right Column (Top Portfolios)
            VStack(alignment: .leading, spacing: 8) {
                Text("Portfolios")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                
                if entry.portfolios.isEmpty {
                    Text("No portfolios yet.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(maxHeight: .infinity)
                } else {
                    VStack(spacing: 8) {
                        ForEach(entry.portfolios.prefix(3)) { item in
                            HStack {
                                Circle()
                                    .fill(Color(hex: item.hexColor))
                                    .frame(width: 8, height: 8)
                                
                                Text(item.name)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(formatCurrency(item.value))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                    
                                    Text(String(format: "%+.1f%%", item.change24h))
                                        .font(.system(size: 8))
                                        .foregroundColor(item.change24h >= 0 ? .green : .red)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
    }
    
    // MARK: - Helpers
    
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
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Portfolio Tracker")
        .description("Track your total investments at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
