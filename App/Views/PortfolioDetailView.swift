import SwiftUI
import SwiftData
import Charts
import StockTrackerCore

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
    
    public init(portfolio: Portfolio) {
        self.portfolio = portfolio
    }
    
    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Subtle glow matching the portfolio color
            Circle()
                .fill(Color(hex: portfolio.hexColor).opacity(0.12))
                .frame(width: 300, height: 300)
                .blur(radius: 70)
                .offset(x: 100, y: -150)
            
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
                                Text(formatCurrency(portfolioTotal, code: "USD"))
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                
                                let secondaryTotal = portfolioTotal * getExchangeRate()
                                Text(formatCurrency(secondaryTotal, code: selectedCurrency))
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            
                            let change = calculator.calculateWeighted24hChange(for: portfolio, prices: priceInfoMap)
                            HStack(spacing: 4) {
                                Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                                Text(String(format: "%.2f%% (24h)", change))
                            }
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(change >= 0 ? .green : .red)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal)
                    
                    // Allocation Chart
                    if portfolioTotal > 0 {
                        GlassmorphicCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Asset Allocation")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                ZStack(alignment: .bottomTrailing) {
                                    // Center: The donut chart diagram
                                    HStack {
                                        Spacer()
                                        Chart {
                                            ForEach(Array(sortedPositions.enumerated()), id: \.element.id) { index, position in
                                                let price = priceMap[position.ticker] ?? 0.0
                                                let val = Double(position.shares) * price
                                                let opacity = 1.0 - (Double(index) / Double(max(sortedPositions.count, 1))) * 0.65
                                                
                                                SectorMark(
                                                    angle: .value("Value", val),
                                                    innerRadius: .ratio(0.7),
                                                    angularInset: 1.5
                                                )
                                                .foregroundStyle(Color(hex: portfolio.hexColor).opacity(opacity))
                                            }
                                        }
                                        .frame(width: 130, height: 130)
                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity)
                                    
                                    // Bottom Right: The legend (names only, even smaller text)
                                    VStack(alignment: .leading, spacing: 6) {
                                        ForEach(Array(sortedPositions.enumerated()), id: \.element.id) { index, position in
                                            let opacity = 1.0 - (Double(index) / Double(max(sortedPositions.count, 1))) * 0.65
                                            HStack(spacing: 6) {
                                                Circle()
                                                    .fill(Color(hex: portfolio.hexColor).opacity(opacity))
                                                    .frame(width: 6, height: 6)
                                                    .shadow(color: Color(hex: portfolio.hexColor).opacity(opacity * 0.5), radius: 1.5, x: 0, y: 0)
                                                
                                                Text(position.ticker)
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(.gray)
                                                    .lineLimit(1)
                                            }
                                        }
                                    }
                                    .padding(.trailing, 8)
                                    .padding(.bottom, 4)
                                }
                                .frame(height: 130)
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
                                        changeText: String(format: "(%.1f%%)", change),
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
            }
        }
        .alert("Rename Portfolio", isPresented: $showingRenameAlert) {
            TextField("Portfolio Name", text: $renameText)
            Button("Save") {
                let clean = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !clean.isEmpty {
                    portfolio.name = clean
                    try? modelContext.save()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete Portfolio?", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                modelContext.delete(portfolio)
                try? modelContext.save()
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
                Color.black.ignoresSafeArea()
                
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
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(ticker)
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text(sharesText)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(valueUSDText)
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(valueSecondaryText)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                
                HStack(spacing: 4) {
                    Text(priceText)
                    Text(changeText)
                        .foregroundColor(isChangePositive ? .green : .red)
                }
                .font(.system(size: 10))
                .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.white.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
