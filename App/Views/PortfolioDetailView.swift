import SwiftUI
import SwiftData
import Charts
import StockTrackerCore

public struct PortfolioDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var portfolio: Portfolio
    @Query private var cachedPrices: [StockPrice]
    
    @State private var showingAddPosition = false
    @State private var positionToEdit: Position? = nil
    @State private var editSharesText = ""
    
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
                            
                            Text(formatCurrency(portfolioTotal))
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
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
                                
                                Chart {
                                    ForEach(portfolio.positions) { position in
                                        let price = priceMap[position.ticker] ?? 0.0
                                        let val = position.shares * price
                                        
                                        BarMark(
                                            x: .value("Asset", position.ticker),
                                            y: .value("Value", val)
                                        )
                                        .foregroundStyle(Color(hex: portfolio.hexColor).opacity(0.8))
                                        .cornerRadius(6)
                                    }
                                }
                                .frame(height: 150)
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
                        
                        if portfolio.positions.isEmpty {
                            Text("No positions added yet. Click 'Add Asset' to start tracking.")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(portfolio.positions) { position in
                                    positionRow(for: position)
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
        .sheet(isPresented: $showingAddPosition) {
            AddPositionView(portfolio: portfolio, isPresented: $showingAddPosition)
        }
        .sheet(item: $positionToEdit) { position in
            EditPositionSheet(position: position, sharesText: $editSharesText) {
                try? modelContext.save()
            }
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
    
    private func formatShares(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 4
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
    
    private func deletePosition(_ position: Position) {
        modelContext.delete(position)
        try? modelContext.save()
    }
    
    @ViewBuilder
    private func positionRow(for position: Position) -> some View {
        let price = priceMap[position.ticker] ?? 0.0
        let change = priceInfoMap[position.ticker]?.change24h ?? 0.0
        let totalVal = position.shares * price
        
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(position.ticker)
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("\(formatShares(position.shares)) shares")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatCurrency(totalVal))
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                HStack(spacing: 4) {
                    Text(formatCurrency(price))
                    Text(String(format: "(%.1f%%)", change))
                        .foregroundColor(change >= 0 ? .green : .red)
                }
                .font(.caption)
                .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                deletePosition(position)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            
            Button {
                editSharesText = String(position.shares)
                positionToEdit = position
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }
}

// MARK: - EditPositionSheet

struct EditPositionSheet: View {
    let position: Position
    @Binding var sharesText: String
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
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
                            .keyboardType(.decimalPad)
                            .padding()
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Button("Save Changes") {
                        if let shares = Double(sharesText) {
                            position.shares = shares
                            onSave()
                        }
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "#00F0FF"))
                    .cornerRadius(16)
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
