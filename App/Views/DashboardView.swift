import SwiftUI
import SwiftData
import Charts
import StockTrackerCore

public struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var portfolios: [Portfolio]
    @Query private var cachedPrices: [StockPrice]
    
    @State private var showingAddPortfolio = false
    @State private var newPortfolioName = ""
    @State private var newPortfolioColor = "#00F0FF"
    @State private var isRefreshing = false
    
    private let calculator = PortfolioCalculator()
    private let priceService = StockPriceService()
    
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
    
    private var grandTotal: Double {
        calculator.calculateGrandTotal(portfolios: portfolios, prices: priceMap)
    }
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                // Neon glow background elements
                Circle()
                    .fill(Color(hex: "#00F0FF").opacity(0.15))
                    .frame(width: 350, height: 350)
                    .blur(radius: 80)
                    .offset(x: -150, y: -200)
                
                Circle()
                    .fill(Color(hex: "#8A2BE2").opacity(0.15))
                    .frame(width: 350, height: 350)
                    .blur(radius: 80)
                    .offset(x: 150, y: 100)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Top Navigation Header
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Good Morning,")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Text("Sarah")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            Button(action: refreshAllPrices) {
                                Image(systemName: isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(Circle())
                                    .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                                    .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                            }
                            .disabled(isRefreshing)
                        }
                        .padding(.horizontal)
                        
                        // Grand Total Glassmorphic Card
                        GlassmorphicCard {
                            VStack(spacing: 12) {
                                Text("Total Balance")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                
                                Text(formatCurrency(grandTotal))
                                    .font(.system(size: 40, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .minimumScaleFactor(0.7)
                                
                                let totalChange = calculateTotal24hChange()
                                HStack(spacing: 4) {
                                    Image(systemName: totalChange >= 0 ? "arrow.up.right" : "arrow.down.left")
                                    Text(String(format: "%.2f%%", totalChange))
                                }
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(totalChange >= 0 ? Color.green : Color.red)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background((totalChange >= 0 ? Color.green : Color.red).opacity(0.15))
                                .clipShape(Capsule())
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .padding(.horizontal)
                        
                        // Allocation Sector Chart
                        if grandTotal > 0 {
                            GlassmorphicCard {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Portfolio Allocation")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Chart {
                                        ForEach(portfolios) { portfolio in
                                            let val = calculator.calculateTotal(for: portfolio, prices: priceMap)
                                            SectorMark(
                                                angle: .value("Value", val),
                                                innerRadius: .ratio(0.65),
                                                angularInset: 2.0
                                            )
                                            .foregroundStyle(Color(hex: portfolio.hexColor))
                                            .annotation(position: .overlay) {
                                                if val / grandTotal > 0.15 {
                                                    Text(portfolio.name)
                                                        .font(.caption2)
                                                        .fontWeight(.bold)
                                                        .foregroundColor(.white)
                                                }
                                            }
                                        }
                                    }
                                    .frame(height: 180)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Portfolio Section list
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("My Portfolios")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Spacer()
                                Button(action: { showingAddPortfolio = true }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                        Text("New")
                                    }
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color(hex: "#00F0FF"))
                                }
                            }
                            .padding(.horizontal)
                            
                            if portfolios.isEmpty {
                                Text("No portfolios created yet. Click 'New' to add one.")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(portfolios) { portfolio in
                                        let total = calculator.calculateTotal(for: portfolio, prices: priceMap)
                                        let pctChange = calculator.calculateWeighted24hChange(for: portfolio, prices: priceInfoMap)
                                        
                                        NavigationLink(destination: PortfolioDetailView(portfolio: portfolio)) {
                                            HStack {
                                                Circle()
                                                    .fill(Color(hex: portfolio.hexColor))
                                                    .frame(width: 12, height: 12)
                                                
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(portfolio.name)
                                                        .font(.body)
                                                        .fontWeight(.bold)
                                                        .foregroundColor(.white)
                                                    
                                                    Text("\(portfolio.positions.count) positions")
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                }
                                                
                                                Spacer()
                                                
                                                VStack(alignment: .trailing, spacing: 4) {
                                                    Text(formatCurrency(total))
                                                        .font(.body)
                                                        .fontWeight(.bold)
                                                        .foregroundColor(.white)
                                                    
                                                    HStack(spacing: 2) {
                                                        Image(systemName: pctChange >= 0 ? "arrow.up" : "arrow.down")
                                                        Text(String(format: "%.2f%%", pctChange))
                                                    }
                                                    .font(.caption)
                                                    .foregroundColor(pctChange >= 0 ? .green : .red)
                                                }
                                                
                                                Image(systemName: "chevron.right")
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                                    .padding(.leading, 8)
                                            }
                                            .padding()
                                            .background(Color.white.opacity(0.04))
                                            .clipShape(RoundedRectangle(cornerRadius: 18))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 18)
                                                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .sheet(isPresented: $showingAddPortfolio) {
                AddPortfolioSheet(isPresented: $showingAddPortfolio, name: $newPortfolioName, color: $newPortfolioColor) {
                    savePortfolio()
                }
            }
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
    
    private func calculateTotal24hChange() -> Double {
        guard grandTotal > 0 else { return 0.0 }
        var weightedSum = 0.0
        for portfolio in portfolios {
            let total = calculator.calculateTotal(for: portfolio, prices: priceMap)
            let pctChange = calculator.calculateWeighted24hChange(for: portfolio, prices: priceInfoMap)
            weightedSum += total * pctChange
        }
        return weightedSum / grandTotal
    }
    
    private func refreshAllPrices() {
        let tickers = Set(portfolios.flatMap { $0.positions.map { $0.ticker } })
        guard !tickers.isEmpty else { return }
        
        isRefreshing = true
        
        Task {
            let prices = await priceService.fetchPrices(for: Array(tickers))
            
            await MainActor.run {
                for (ticker, value) in prices {
                    if let existing = cachedPrices.first(where: { $0.ticker == ticker }) {
                        existing.price = value.price
                        existing.change24h = value.change24h
                        existing.lastUpdated = Date()
                    } else {
                        let newPrice = StockPrice(ticker: ticker, price: value.price, change24h: value.change24h)
                        modelContext.insert(newPrice)
                    }
                }
                try? modelContext.save()
                isRefreshing = false
            }
        }
    }
    
    private func savePortfolio() {
        let cleanName = newPortfolioName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        let newPortfolio = Portfolio(name: cleanName, hexColor: newPortfolioColor)
        modelContext.insert(newPortfolio)
        try? modelContext.save()
        newPortfolioName = ""
    }
}

// MARK: - AddPortfolioSheet

struct AddPortfolioSheet: View {
    @Binding var isPresented: Bool
    @Binding var name: String
    @Binding var color: String
    var onSave: () -> Void
    
    let colors = ["#00F0FF", "#8A2BE2", "#FF007F", "#FFD700", "#00FF87", "#FF5733"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Portfolio Name")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .textCase(.uppercase)
                        
                        TextField("e.g. Retirement, Crypto", text: $name)
                            .padding()
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Accent Color")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .textCase(.uppercase)
                        
                        HStack(spacing: 16) {
                            ForEach(colors, id: \.self) { c in
                                Circle()
                                    .fill(Color(hex: c))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: color == c ? 3 : 0)
                                    )
                                    .onTapGesture {
                                        color = c
                                    }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        onSave()
                        isPresented = false
                    }) {
                        Text("Create Portfolio")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(LinearGradient(colors: [Color(hex: "#00F0FF"), Color(hex: "#8A2BE2")], startPoint: .leading, endPoint: .trailing))
                            .cornerRadius(16)
                            .shadow(color: Color(hex: "#00F0FF").opacity(0.3), radius: 10)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
            }
            .navigationTitle("New Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.gray)
                }
            }
        }
    }
}
