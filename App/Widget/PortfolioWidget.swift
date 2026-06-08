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
    let secondaryCurrency: String
    let exchangeRate: Double
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
            ],
            secondaryCurrency: "EUR",
            exchangeRate: 0.92
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
        
        items.sort(by: { $0.value > $1.value })
        
        let totalChange = total > 0 ? (weightedSum / total) : 0.0
        let latestUpdate = cachedPrices.map { $0.lastUpdated }.max() ?? Date()
        
        // Fetch selected currency and exchange rate
        let selectedCurrency = AppGroupSettings.shared.selectedSecondaryCurrency
        let rateTicker = AppGroupSettings.shared.getExchangeRateTicker(for: selectedCurrency)
        let rate = priceMap[rateTicker] ?? {
            switch selectedCurrency {
            case "EUR": return 0.92
            case "GBP": return 0.78
            case "CAD": return 1.36
            case "ILS": return 3.72
            case "JPY": return 156.40
            case "AUD": return 1.50
            case "CHF": return 0.89
            default: return 1.0
            }
        }()
        
        return PortfolioEntry(
            date: Date(),
            totalValue: total,
            dayChangePercent: totalChange,
            lastUpdated: latestUpdate,
            portfolios: items,
            secondaryCurrency: selectedCurrency,
            exchangeRate: rate
        )
    }
}

struct PortfolioWidgetEntryView: View {
    var entry: PortfolioProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        Group {
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
        VStack(alignment: .leading, spacing: 4) {
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
            
            VStack(alignment: .leading, spacing: 2) {
                Text(formatCurrency(entry.totalValue, code: "USD"))
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.8)
                
                let secondaryVal = entry.totalValue * entry.exchangeRate
                Text(formatCurrency(secondaryVal, code: entry.secondaryCurrency))
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
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
            VStack(alignment: .leading, spacing: 4) {
                Text("Total Balance")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatCurrency(entry.totalValue, code: "USD"))
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.7)
                    
                    let secondaryVal = entry.totalValue * entry.exchangeRate
                    Text(formatCurrency(secondaryVal, code: entry.secondaryCurrency))
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
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
                                    Text(formatCurrency(item.value, code: "USD"))
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    let secondaryVal = item.value * entry.exchangeRate
                                    Text(formatCurrency(secondaryVal, code: entry.secondaryCurrency))
                                        .font(.system(size: 8))
                                        .foregroundColor(.white.opacity(0.6))
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
    
    private func formatCurrency(_ value: Double, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = AppGroupSettings.shared.getSymbol(for: code)
        return formatter.string(from: NSNumber(value: value)) ?? "\(AppGroupSettings.shared.getSymbol(for: code))0.00"
    }
}

@main
struct PortfolioWidget: Widget {
    let kind: String = "PortfolioWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PortfolioProvider()) { entry in
            PortfolioWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    ZStack {
                        Color.black
                        RadialGradient(
                            colors: [Color(hex: "#8A2BE2").opacity(0.25), Color.black],
                            center: .bottomTrailing,
                            startRadius: 5,
                            endRadius: 90
                        )
                    }
                }
        }
        .configurationDisplayName("Portfolio Tracker")
        .description("Track your total investments at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
