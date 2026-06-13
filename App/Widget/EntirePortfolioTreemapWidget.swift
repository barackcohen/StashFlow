import WidgetKit
import SwiftUI
import SwiftData
import StockTrackerCore

struct TreemapItem {
    let ticker: String
    let value: Double
    let change24h: Double
}

struct TreemapNode: Identifiable {
    let id = UUID()
    let ticker: String
    let value: Double
    let change24h: Double
    let percentage: Double
    let rect: CGRect
}

struct TreemapWidgetEntry: TimelineEntry {
    let date: Date
    let items: [TreemapItem]
    let totalValue: Double
    let dayChangePercent: Double
    let lastUpdated: Date
}

struct TreemapWidgetProvider: TimelineProvider {
    typealias Entry = TreemapWidgetEntry
    
    private let calculator = PortfolioCalculator()
    
    func placeholder(in context: Context) -> TreemapWidgetEntry {
        TreemapWidgetEntry(
            date: Date(),
            items: [
                TreemapItem(ticker: "AAPL", value: 45000.0, change24h: 1.8),
                TreemapItem(ticker: "MSFT", value: 35000.0, change24h: -0.5),
                TreemapItem(ticker: "TSLA", value: 25000.0, change24h: 3.2),
                TreemapItem(ticker: "NVDA", value: 15000.0, change24h: -1.2)
            ],
            totalValue: 120000.0,
            dayChangePercent: 0.98,
            lastUpdated: Date()
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (TreemapWidgetEntry) -> Void) {
        let entry = loadCurrentData()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TreemapWidgetEntry>) -> Void) {
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
    
    private func loadCurrentData() -> TreemapWidgetEntry {
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
        
        var aggregatedShares: [String: Double] = [:]
        for portfolio in portfolios {
            for position in portfolio.positions {
                aggregatedShares[position.ticker, default: 0.0] += position.shares
            }
        }
        
        var treemapItems: [TreemapItem] = []
        var total = 0.0
        var weightedSum = 0.0
        
        for (ticker, shares) in aggregatedShares {
            let price = priceMap[ticker] ?? 0.0
            let change = priceInfoMap[ticker]?.change24h ?? 0.0
            let val = shares * price
            
            if val > 0 {
                total += val
                weightedSum += val * change
                treemapItems.append(TreemapItem(ticker: ticker, value: val, change24h: change))
            }
        }
        
        treemapItems.sort { $0.value > $1.value }
        
        let totalChange = total > 0 ? (weightedSum / total) : 0.0
        let latestUpdate = cachedPrices.map { $0.lastUpdated }.max() ?? Date()
        
        return TreemapWidgetEntry(
            date: Date(),
            items: treemapItems,
            totalValue: total,
            dayChangePercent: totalChange,
            lastUpdated: latestUpdate
        )
    }
}

struct EntirePortfolioTreemapWidgetEntryView: View {
    var entry: TreemapWidgetProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Total Assets")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                    
                    Text(formatCurrency(entry.totalValue, code: "USD"))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                
                Spacer()
                
                HStack(spacing: 3) {
                    Image(systemName: entry.dayChangePercent >= 0 ? "arrow.up" : "arrow.down")
                        .font(.system(size: 9, weight: .bold))
                    Text(String(format: "%.2f%%", abs(entry.dayChangePercent)))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(entry.dayChangePercent >= 0 ? Color(hex: "#306E43") : Color(hex: "#8F3B3B"))
                )
            }
            .padding(.horizontal, 2)
            
            if entry.items.isEmpty {
                VStack {
                    Spacer()
                    Text("No positions added.")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                    Spacer()
                }
            } else {
                TreemapWidgetView(items: entry.items)
            }
        }
        .padding(10)
    }
    
    private func formatCurrency(_ value: Double, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = AppGroupSettings.shared.getSymbol(for: code)
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(AppGroupSettings.shared.getSymbol(for: code))0"
    }
}

struct TreemapWidgetView: View {
    let items: [TreemapItem]
    
    var body: some View {
        GeometryReader { geo in
            let nodes = layoutTreemap(items: items, rect: CGRect(origin: .zero, size: geo.size))
            ZStack(alignment: .topLeading) {
                ForEach(nodes) { node in
                    Link(destination: URL(string: "stashflow://ticker/\(node.ticker)") ?? URL(string: "stashflow://")!) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(getTreemapColor(change: node.change24h))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                            
                            if node.rect.width > 35 && node.rect.height > 25 {
                                VStack(spacing: 1) {
                                    Text(node.ticker)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    
                                    Text(String(format: "%.0f%%", node.percentage * 100))
                                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.8))
                                        .lineLimit(1)
                                }
                                .padding(2)
                            } else if node.rect.width > 20 && node.rect.height > 14 {
                                Text(node.ticker)
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .frame(width: max(0, node.rect.width - 1.5), height: max(0, node.rect.height - 1.5))
                    .position(x: node.rect.midX, y: node.rect.midY)
                }
            }
        }
    }
    
    private func getTreemapColor(change: Double) -> Color {
        let absChange = abs(change)
        if change > 0 {
            if absChange >= 3.0 {
                return Color(hex: "#306E43")
            } else if absChange >= 1.5 {
                return Color(hex: "#3C7C51")
            } else if absChange >= 0.5 {
                return Color(hex: "#4E8E62")
            } else {
                return Color(hex: "#65A37A")
            }
        } else if change < 0 {
            if absChange >= 3.0 {
                return Color(hex: "#8F3B3B")
            } else if absChange >= 1.5 {
                return Color(hex: "#A04C4C")
            } else if absChange >= 0.5 {
                return Color(hex: "#B36060")
            } else {
                return Color(hex: "#C27575")
            }
        } else {
            return Color(hex: "#2C313E")
        }
    }
    
    private func layoutTreemap(items: [TreemapItem], rect: CGRect) -> [TreemapNode] {
        guard !items.isEmpty && rect.width > 0 && rect.height > 0 else { return [] }
        
        let totalValue = items.reduce(0.0) { $0 + $1.value }
        guard totalValue > 0 else { return [] }
        
        let sortedItems = items.sorted { $0.value > $1.value }
        var nodes: [TreemapNode] = []
        
        func partition(subItems: ArraySlice<TreemapItem>, subRect: CGRect) {
            if subItems.isEmpty { return }
            
            if subItems.count == 1 {
                let item = subItems.first!
                let pct = item.value / totalValue
                nodes.append(TreemapNode(ticker: item.ticker, value: item.value, change24h: item.change24h, percentage: pct, rect: subRect))
                return
            }
            
            let subTotal = subItems.reduce(0.0) { $0 + $1.value }
            var currentSum = 0.0
            var bestIndex = subItems.startIndex
            var minDiff = Double.infinity
            
            for index in subItems.indices {
                currentSum += subItems[index].value
                let diff = abs((subTotal / 2.0) - currentSum)
                if diff < minDiff {
                    minDiff = diff
                    bestIndex = index
                }
            }
            
            let splitIndex = Swift.max(subItems.startIndex + 1, Swift.min(bestIndex + 1, subItems.endIndex - 1))
            
            let leftSlice = subItems[subItems.startIndex..<splitIndex]
            let rightSlice = subItems[splitIndex..<subItems.endIndex]
            
            let leftSum = leftSlice.reduce(0.0) { $0 + $1.value }
            let rightSum = rightSlice.reduce(0.0) { $0 + $1.value }
            let sum = leftSum + rightSum
            let leftRatio = sum > 0 ? (leftSum / sum) : 0.5
            
            if subRect.width > subRect.height {
                let leftWidth = subRect.width * CGFloat(leftRatio)
                let rightWidth = subRect.width - leftWidth
                
                let leftRect = CGRect(x: subRect.minX, y: subRect.minY, width: leftWidth, height: subRect.height)
                let rightRect = CGRect(x: subRect.minX + leftWidth, y: subRect.minY, width: rightWidth, height: subRect.height)
                
                partition(subItems: leftSlice, subRect: leftRect)
                partition(subItems: rightSlice, subRect: rightRect)
            } else {
                let topHeight = subRect.height * CGFloat(leftRatio)
                let bottomHeight = subRect.height - topHeight
                
                let topRect = CGRect(x: subRect.minX, y: subRect.minY, width: subRect.width, height: topHeight)
                let bottomRect = CGRect(x: subRect.minX, y: subRect.minY + topHeight, width: subRect.width, height: bottomHeight)
                
                partition(subItems: leftSlice, subRect: topRect)
                partition(subItems: rightSlice, subRect: bottomRect)
            }
        }
        
        partition(subItems: ArraySlice(sortedItems), subRect: rect)
        return nodes
    }
}

struct EntirePortfolioTreemapWidget: Widget {
    let kind: String = "EntirePortfolioTreemapWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TreemapWidgetProvider()) { entry in
            EntirePortfolioTreemapWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(hex: "#232835")
                }
        }
        .contentMarginsDisabled()
        .configurationDisplayName("Entire Portfolio Treemap")
        .description("Visual breakdown of your entire stock allocation by value.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
