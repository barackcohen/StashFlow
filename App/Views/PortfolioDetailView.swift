import SwiftUI
import SwiftData
import Charts
import StockTrackerCore
import WidgetKit

public struct PortfolioDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var portfolio: Portfolio
    @Query private var cachedPrices: [StockPrice]
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingAddPosition = false
    @State private var positionToEdit: Position? = nil
    @State private var editSharesText = ""
    @State private var showingRenameAlert = false
    @State private var renameText = ""
    @State private var showingDeleteAlert = false
    @State private var showingTreemap = true
    
    private let calculator = PortfolioCalculator()
    
    private var priceMap: [String: Double] {
        var map: [String: Double] = [:]
        for price in cachedPrices {
            map[price.ticker] = price.price
        }
        return map
    }
    
    private var priceInfoMap: [String: (price: Double, change24h: Double)] {
        var map: [String: (price: Double, change24h: Double)] = [:]
        for price in cachedPrices {
            map[price.ticker] = (price.price, price.change24h)
        }
        return map
    }
    
    private var portfolioTotal: Double {
        calculator.calculateTotal(for: portfolio, prices: priceMap)
    }
    
    private var sortedPositions: [Position] {
        portfolio.positions.sorted { p1, p2 in
            let val1 = Double(p1.shares) * (priceMap[p1.ticker] ?? 0.0)
            let val2 = Double(p2.shares) * (priceMap[p2.ticker] ?? 0.0)
            return val1 > val2
        }
    }
    
    // Removed old circular chart structures
    
    private var selectedCurrency: String {
        AppGroupSettings.shared.selectedSecondaryCurrency
    }
    
    private func getExchangeRate() -> Double {
        let ticker = AppGroupSettings.shared.getExchangeRateTicker(for: selectedCurrency)
        if let priceObj = cachedPrices.first(where: { $0.ticker == ticker }) {
            return priceObj.price
        }
        // Fallback
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
    }
    
    private func formatCurrency(_ value: Double, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = AppGroupSettings.shared.getSymbol(for: code)
        return formatter.string(from: NSNumber(value: value)) ?? "\(AppGroupSettings.shared.getSymbol(for: code))0.00"
    }
    
    private func formatCurrencyNoCents(_ value: Double, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = AppGroupSettings.shared.getSymbol(for: code)
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(AppGroupSettings.shared.getSymbol(for: code))0"
    }
    
    public init(portfolio: Portfolio) {
        self.portfolio = portfolio
    }
    
    public var body: some View {
        ZStack {
            Color(hex: "#232835").ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    // Portfolio Header Card
                    GlassmorphicCard {
                        VStack(spacing: 8) {
                            Text(portfolio.name)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            VStack(spacing: 4) {
                                Text(formatCurrencyNoCents(portfolioTotal, code: "USD"))
                                    .font(.system(size: 34, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                
                                let secondaryTotal = portfolioTotal * getExchangeRate()
                                Text(formatCurrencyNoCents(secondaryTotal, code: selectedCurrency))
                                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.gray)
                            }
                            
                            let change = calculator.calculateWeighted24hChange(for: portfolio, prices: priceInfoMap)
                            HStack(spacing: 4) {
                                Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                                Text(String(format: "%@%.2f%%", change >= 0 ? "+" : "", change))
                            }
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(change >= 0 ? Color(hex: "#30D158") : Color(hex: "#FF453A"))
                            .cornerRadius(6)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal)
                    
                    // Treemap Diagram Card
                    if portfolioTotal > 0 {
                        GlassmorphicCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Portfolio Treemap")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        withAnimation(.spring()) {
                                            showingTreemap.toggle()
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            Text(showingTreemap ? "Hide" : "Show")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            Image(systemName: showingTreemap ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                                
                                if showingTreemap {
                                    let treemapItems = sortedPositions.map { p in
                                        let price = priceMap[p.ticker] ?? 0.0
                                        let change = priceInfoMap[p.ticker]?.change24h ?? 0.0
                                        return TreemapItem(ticker: p.ticker, value: Double(p.shares) * price, change24h: change)
                                    }.filter { $0.value > 0 }
                                    
                                    TreemapView(items: treemapItems) { ticker in
                                        if let pos = sortedPositions.first(where: { $0.ticker == ticker }) {
                                            editSharesText = String(pos.shares)
                                            positionToEdit = pos
                                        }
                                    }
                                    .frame(height: 200)
                                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Positions List
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Positions")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                            Button(action: { showingAddPosition = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add Asset")
                                }
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(Color(hex: portfolio.hexColor))
                            }
                        }
                        .padding(.horizontal)
                        
                        if sortedPositions.isEmpty {
                            Text("No positions added yet. Click 'Add Asset' to start tracking.")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(sortedPositions) { position in
                                    let price = priceMap[position.ticker] ?? 0.0
                                    let change = priceInfoMap[position.ticker]?.change24h ?? 0.0
                                    let totalVal = Double(position.shares) * price
                                    let secondaryVal = totalVal * getExchangeRate()
                                    
                                    PositionRow(
                                        ticker: position.ticker,
                                        sharesText: "\(formatShares(position.shares, ticker: position.ticker)) shares",
                                        valueUSDText: formatCurrency(totalVal, code: "USD"),
                                        valueSecondaryText: formatCurrency(secondaryVal, code: selectedCurrency),
                                        priceText: formatCurrency(price, code: "USD"),
                                        changeText: String(format: "%@%.2f%%", change >= 0 ? "+" : "", change),
                                        isChangePositive: change >= 0,
                                        hexColor: portfolio.hexColor,
                                        onEdit: {
                                            editSharesText = String(position.shares)
                                            positionToEdit = position
                                        },
                                        onDelete: {
                                            deletePosition(position)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle(portfolio.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        renameText = portfolio.name
                        showingRenameAlert = true
                    } label: {
                        Label("Rename Portfolio", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete Portfolio", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(Color(hex: portfolio.hexColor))
                }
            }
        }
        .sheet(isPresented: $showingAddPosition) {
            AddPositionView(portfolio: portfolio, isPresented: $showingAddPosition)
        }
        .sheet(item: $positionToEdit) { position in
            EditPositionSheet(position: position, sharesText: $editSharesText) {
                try? modelContext.save()
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        .alert("Rename Portfolio", isPresented: $showingRenameAlert) {
            TextField("Portfolio Name", text: $renameText)
            Button("Save") {
                let clean = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !clean.isEmpty {
                    portfolio.name = clean
                    try? modelContext.save()
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete Portfolio?", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                modelContext.delete(portfolio)
                try? modelContext.save()
                WidgetCenter.shared.reloadAllTimelines()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete '\(portfolio.name)'? This action cannot be undone.")
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        return formatCurrency(value, code: "USD")
    }
    
    private func formatShares(_ value: Double, ticker: String) -> String {
        let isCrypto = ticker.uppercased().contains("-USD") || ticker.uppercased().contains("=X")
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        if isCrypto {
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 4
        } else {
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 0
        }
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
    
    private func deletePosition(_ position: Position) {
        modelContext.delete(position)
        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // SwipeablePositionRow is defined below as a separate view struct.
}

// MARK: - EditPositionSheet

struct EditPositionSheet: View {
    let position: Position
    @Binding var sharesText: String
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    private var isCrypto: Bool {
        position.ticker.uppercased().contains("-USD") || position.ticker.uppercased().contains("=X")
    }
    
    private var parsedShares: Double? {
        let cleanText = sharesText.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let val = Double(cleanText) else { return nil }
        
        if isCrypto {
            return val
        } else {
            if val == floor(val) {
                return val
            }
            return nil
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#232835").ignoresSafeArea()
                
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Edit shares for \(position.ticker)")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        TextField("Number of shares", text: $sharesText)
                            .keyboardType(isCrypto ? .decimalPad : .numberPad)
                            .padding()
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(parsedShares == nil && !sharesText.isEmpty ? Color.red.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                            )
                        
                        if parsedShares == nil && !sharesText.isEmpty {
                            Text(isCrypto ? "Please enter a valid number of shares." : "Please enter a valid integer number of shares.")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    Spacer()
                    
                    Button("Save Changes") {
                        if let shares = parsedShares, shares > 0 {
                            position.shares = shares
                            onSave()
                            dismiss()
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(parsedShares != nil && (parsedShares ?? 0) > 0 ? Color(hex: "#00F0FF") : Color.gray.opacity(0.3))
                    .cornerRadius(16)
                    .disabled(parsedShares == nil || (parsedShares ?? 0) <= 0)
                }
                .padding()
            }
            .navigationTitle("Edit Position")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }
            }
        }
    }
}

// MARK: - PositionRow

struct PositionRow: View {
    let ticker: String
    let sharesText: String
    let valueUSDText: String
    let valueSecondaryText: String
    let priceText: String
    let changeText: String
    let isChangePositive: Bool
    let hexColor: String
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(ticker)
                    .font(.system(.body, design: .default))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text(sharesText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(valueUSDText)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(valueSecondaryText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.gray)
            }
            
            // Apple Stocks style price + change pill
            VStack(alignment: .trailing, spacing: 2) {
                Text(priceText)
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                
                if !changeText.isEmpty {
                    Text(changeText)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isChangePositive ? Color(hex: "#30D158") : Color(hex: "#FF453A"))
                        .cornerRadius(4)
                }
            }
            .frame(width: 98, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.black.opacity(0.3))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit Shares", systemImage: "pencil")
            }
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Position", systemImage: "trash")
            }
        }
    }
}

// MARK: - Treemap Data Types & Views

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

struct TreemapView: View {
    let items: [TreemapItem]
    let onSelect: (String) -> Void
    
    var body: some View {
        GeometryReader { geo in
            let nodes = layoutTreemap(items: items, rect: CGRect(origin: .zero, size: geo.size))
            ZStack(alignment: .topLeading) {
                ForEach(nodes) { node in
                    Button(action: {
                        onSelect(node.ticker)
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(getTreemapColor(change: node.change24h))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                            
                            if node.rect.width > 45 && node.rect.height > 35 {
                                VStack(spacing: 2) {
                                    Text(node.ticker)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    
                                    Text(String(format: "%.1f%%", node.percentage * 100))
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.8))
                                        .lineLimit(1)
                                }
                                .padding(4)
                            } else if node.rect.width > 28 && node.rect.height > 18 {
                                Text(node.ticker)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .padding(2)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: max(0, node.rect.width - 2), height: max(0, node.rect.height - 2))
                    .position(x: node.rect.midX, y: node.rect.midY)
                }
            }
        }
    }
    
    private func getTreemapColor(change: Double) -> Color {
        let absChange = abs(change)
        if change > 0 {
            if absChange >= 3.0 {
                return Color(hex: "#306E43") // Muted forest green
            } else if absChange >= 1.5 {
                return Color(hex: "#3C7C51") // Muted medium green
            } else if absChange >= 0.5 {
                return Color(hex: "#4E8E62") // Muted sage green
            } else {
                return Color(hex: "#65A37A") // Muted soft green
            }
        } else if change < 0 {
            if absChange >= 3.0 {
                return Color(hex: "#8F3B3B") // Muted dark red
            } else if absChange >= 1.5 {
                return Color(hex: "#A04C4C") // Muted brick red
            } else if absChange >= 0.5 {
                return Color(hex: "#B36060") // Muted dusty red
            } else {
                return Color(hex: "#C27575") // Muted soft red
            }
        } else {
            return Color(hex: "#2C313E") // Flat slate
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
