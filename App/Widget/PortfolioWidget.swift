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
        Task {
            await fetchFreshPrices()
            let entry = loadCurrentData()
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 10, to: Date()) ?? Date()
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
    
    private func fetchFreshPrices() async {
        let context = ModelContext(StorageManager.shared.modelContainer)
        let positionsDescriptor = FetchDescriptor<Position>()
        let positions = (try? context.fetch(positionsDescriptor)) ?? []
        
        let selectedCurrency = AppGroupSettings.shared.selectedSecondaryCurrency
        let rateTicker = AppGroupSettings.shared.getExchangeRateTicker(for: selectedCurrency)
        
        var tickers = Array(Set(positions.map { $0.ticker }))
        tickers.append(rateTicker)
        
        guard !tickers.isEmpty else { return }
        
        let service = StockPriceService()
        let fetched = await service.fetchPrices(for: tickers)
        
        let pricesDescriptor = FetchDescriptor<StockPrice>()
        let cachedPrices = (try? context.fetch(pricesDescriptor)) ?? []
        
        for (ticker, val) in fetched {
            if let existing = cachedPrices.first(where: { $0.ticker == ticker }) {
                existing.price = val.price
                existing.change24h = val.change24h
                existing.lastUpdated = Date()
            } else {
                let newPrice = StockPrice(ticker: ticker, price: val.price, change24h: val.change24h)
                context.insert(newPrice)
            }
        }
        try? context.save()
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
    @Environment(\.widgetRenderingMode) var renderingMode
    
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
    
    // MARK: - Badge Helper
    
    @ViewBuilder
    private func badgeView(change: Double, fontSize: CGFloat = 11) -> some View {
        let text = String(format: "%@%.2f%%", change >= 0 ? "+" : "", change)
        let isPositive = change >= 0
        let hPadding: CGFloat = fontSize <= 10 ? 6 : 8
        let vPadding: CGFloat = fontSize <= 10 ? 3 : 4
        let cornerRadius: CGFloat = fontSize <= 10 ? 3 : 4
        
        if renderingMode == .fullColor {
            Text(text)
                .font(.system(size: fontSize, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, hPadding)
                .padding(.vertical, vPadding)
                .background(isPositive ? Color(hex: "#30D158") : Color(hex: "#FF453A"))
                .cornerRadius(cornerRadius)
        } else {
            // Accented/tinted or vibrant mode:
            // Use transparent/dark capsule with colored border and colored text.
            // When desaturated, this will map perfectly to a high-contrast layout.
            Text(text)
                .font(.system(size: fontSize, weight: .bold, design: .monospaced))
                .foregroundColor(isPositive ? Color(hex: "#30D158") : Color(hex: "#FF453A"))
                .padding(.horizontal, hPadding)
                .padding(.vertical, vPadding)
                .background(Color.black.opacity(0.6))
                .cornerRadius(cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(isPositive ? Color(hex: "#30D158") : Color(hex: "#FF453A"), lineWidth: 1)
                )
        }
    }
    
    // MARK: - Small Layout
    
    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Spacer()
                
                Button(intent: RefreshPricesIntent()) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(5)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 1) {
                Text(formatCurrency(entry.totalValue, code: "USD"))
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.7)
                
                let secondaryVal = entry.totalValue * entry.exchangeRate
                Text(formatCurrency(secondaryVal, code: entry.secondaryCurrency))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                    .minimumScaleFactor(0.7)
            }
            
            Spacer()
            
            badgeView(change: entry.dayChangePercent)
            
            Spacer()
            
            Text("Updated: \(entry.lastUpdated, style: .time)")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(12)
    }
    
    // MARK: - Medium Layout
    
    private var mediumLayout: some View {
        let limit = min(entry.portfolios.count, 4)
        let itemSpacing: CGFloat = limit > 3 ? 4 : (limit > 2 ? 6 : 10)
        let nameFontSize: CGFloat = limit > 3 ? 11 : (limit > 2 ? 12 : 13)
        let valueFontSize: CGFloat = limit > 3 ? 9 : (limit > 2 ? 10 : 11)
        let dotSize: CGFloat = limit > 3 ? 6 : 8
        let indentSize: CGFloat = dotSize + 6
        let gap: CGFloat = 16

        return HStack(spacing: gap) {
            // Left Column (Total Balance summary)
            VStack(alignment: .leading, spacing: 8) {
                Spacer(minLength: 0)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(formatCurrency(entry.totalValue, code: "USD"))
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.7)
                    
                    let secondaryVal = entry.totalValue * entry.exchangeRate
                    Text(formatCurrency(secondaryVal, code: entry.secondaryCurrency))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                        .minimumScaleFactor(0.7)
                }
                
                badgeView(change: entry.dayChangePercent)
                
                Spacer(minLength: 0)
                
                HStack(spacing: 6) {
                    Button(intent: RefreshPricesIntent()) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(6)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Text("\(entry.lastUpdated, style: .time)")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .frame(width: 86, alignment: .leading)
            
            Divider()
                .background(Color.white.opacity(0.08))
            
            // Right Column (Top Portfolios)
            VStack(alignment: .leading, spacing: 0) {
                if entry.portfolios.isEmpty {
                    Text("No portfolios yet.")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                        .frame(maxHeight: .infinity)
                } else {
                    Spacer(minLength: 0)
                    
                    VStack(spacing: itemSpacing) {
                        ForEach(entry.portfolios.prefix(limit)) { item in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    RoundedRectangle(cornerRadius: 1)
                                        .fill(Color(hex: item.hexColor))
                                        .frame(width: 3, height: 18)
                                    
                                    Text(item.name)
                                        .font(.system(size: nameFontSize, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .layoutPriority(1)
                                    
                                    Spacer()
                                    
                                    badgeView(change: item.change24h, fontSize: nameFontSize - 1)
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                                
                                HStack(spacing: 4) {
                                    Spacer()
                                        .frame(width: indentSize - 4)
                                    
                                    Text(formatCurrency(item.value, code: "USD"))
                                        .font(.system(size: valueFontSize, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                    
                                    Text("•")
                                        .font(.system(size: valueFontSize))
                                        .foregroundColor(.white.opacity(0.3))
                                    
                                    let secondaryVal = item.value * entry.exchangeRate
                                    Text(formatCurrency(secondaryVal, code: entry.secondaryCurrency))
                                        .font(.system(size: valueFontSize, weight: .semibold, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.5))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, gap)
        .padding(.vertical, 12)
    }
    
    // MARK: - Helpers
    
    private func formatCurrency(_ value: Double, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = AppGroupSettings.shared.getSymbol(for: code)
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(AppGroupSettings.shared.getSymbol(for: code))0"
    }
}

@main
struct PortfolioWidget: Widget {
    let kind: String = "PortfolioWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PortfolioProvider()) { entry in
            PortfolioWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(hex: "#232835")
                }
        }
        .contentMarginsDisabled()
        .configurationDisplayName("Portfolio Tracker")
        .description("Track your total investments at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
