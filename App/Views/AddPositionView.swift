import SwiftUI
import SwiftData
import StockTrackerCore

public struct AddPositionView: View {
    let portfolio: Portfolio
    @Binding var isPresented: Bool
    
    @Environment(\.modelContext) private var modelContext
    @Query private var cachedPrices: [StockPrice]
    
    @State private var ticker = ""
    @State private var sharesText = ""
    @State private var isValidating = false
    @State private var errorMessage = ""
    @FocusState private var isTickerFocused: Bool
    @State private var searchResults: [SymbolSearchResult] = []
    @State private var isSearching = false
    
    private let priceService = StockPriceService()
    
    public init(portfolio: Portfolio, isPresented: Binding<Bool>) {
        self.portfolio = portfolio
        self._isPresented = isPresented
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                    .onTapGesture {
                        isTickerFocused = false
                    }
                
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ticker Symbol")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .textCase(.uppercase)
                        
                        ZStack(alignment: .top) {
                            TextField("e.g. AAPL, TSLA, MSFT", text: $ticker)
                                .focused($isTickerFocused)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.characters)
                                .padding()
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(12)
                                .foregroundColor(.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                                .overlay(
                                    HStack {
                                        Spacer()
                                        if isSearching {
                                            ProgressView()
                                                .tint(.white)
                                                .padding(.trailing, 16)
                                        }
                                    }
                                )
                            
                            if isTickerFocused && !searchResults.isEmpty {
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 0) {
                                        ForEach(searchResults) { result in
                                            Button(action: {
                                                ticker = result.symbol
                                                searchResults = []
                                                isTickerFocused = false
                                            }) {
                                                HStack(spacing: 12) {
                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Text(result.symbol)
                                                            .font(.system(.headline, design: .monospaced))
                                                            .foregroundColor(.white)
                                                        
                                                        if let name = result.longname ?? result.shortname {
                                                            Text(name)
                                                                .font(.caption)
                                                                .foregroundColor(.gray)
                                                                .lineLimit(1)
                                                                .multilineTextAlignment(.leading)
                                                        }
                                                    }
                                                    
                                                    Spacer()
                                                    
                                                    if let exch = result.exchDisp ?? (result.exchange.isEmpty ? nil : result.exchange) {
                                                        Text(exch)
                                                            .font(.caption2)
                                                            .fontWeight(.semibold)
                                                            .padding(.horizontal, 8)
                                                            .padding(.vertical, 4)
                                                            .background(Color.white.opacity(0.1))
                                                            .cornerRadius(6)
                                                            .foregroundColor(.gray)
                                                    }
                                                    
                                                    if let type = result.typeDisp {
                                                        Text(type)
                                                            .font(.system(.caption2, design: .monospaced))
                                                            .fontWeight(.bold)
                                                            .padding(.horizontal, 8)
                                                            .padding(.vertical, 4)
                                                            .background(Color.white.opacity(0.12))
                                                            .cornerRadius(4)
                                                            .foregroundColor(.white)
                                                    }
                                                }
                                                .padding(.vertical, 12)
                                                .padding(.horizontal, 16)
                                                .contentShape(Rectangle())
                                            }
                                            
                                            if result.symbol != searchResults.last?.symbol {
                                                Divider()
                                                    .background(Color.white.opacity(0.1))
                                            }
                                        }
                                    }
                                }
                                .frame(maxHeight: 220)
                                .background(Color(hex: "#121212").opacity(0.95))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.5), radius: 10, x: 0, y: 10)
                                .offset(y: 58)
                            }
                        }
                    }
                    .zIndex(1)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Number of Shares")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .textCase(.uppercase)
                        
                        TextField(isCrypto ? "e.g. 0.5 or 10" : "e.g. 10", text: $sharesText)
                            .keyboardType(isCrypto ? .decimalPad : .numberPad)
                            .padding()
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    Spacer()
                    
                    Button(action: validateAndSavePosition) {
                        HStack {
                            if isValidating {
                                ProgressView()
                                    .tint(.black)
                                    .padding(.trailing, 8)
                            }
                            Text(isValidating ? "Validating Ticker..." : "Add Position")
                                .font(.system(.headline, design: .default))
                                .fontWeight(.bold)
                        }
                        .foregroundColor(ticker.isEmpty || sharesText.isEmpty || isValidating ? .gray : .black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(ticker.isEmpty || sharesText.isEmpty || isValidating ? Color.white.opacity(0.15) : Color.white)
                        .cornerRadius(10)
                    }
                    .disabled(ticker.isEmpty || sharesText.isEmpty || isValidating)
                }
                .padding()
            }
            .navigationTitle("Add Position")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.gray)
                }
            }
            .task(id: ticker) {
                let cleanTicker = ticker.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleanTicker.isEmpty else {
                    searchResults = []
                    isSearching = false
                    return
                }
                
                guard isTickerFocused else { return }
                
                isSearching = true
                do {
                    try await Task.sleep(for: .seconds(0.3))
                    
                    let results = try await priceService.searchSymbols(query: cleanTicker)
                    await MainActor.run {
                        self.searchResults = results
                        self.isSearching = false
                    }
                } catch {
                    if !Task.isCancelled {
                        await MainActor.run {
                            self.isSearching = false
                        }
                    }
                }
            }
        }
    }
    
    private var isCrypto: Bool {
        let clean = ticker.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.contains("-USD") || clean.contains("=X")
    }
    
    private func validateAndSavePosition() {
        let cleanTicker = ticker.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTicker.isEmpty else { return }
        
        let cleanSharesText = sharesText.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        
        guard let shares = Double(cleanSharesText), shares > 0 else {
            errorMessage = isCrypto ? "Please enter a valid positive number of shares." : "Please enter a valid positive integer number of shares."
            return
        }
        
        if !isCrypto && shares != floor(shares) {
            errorMessage = "Stocks do not support fractional shares. Please enter an integer."
            return
        }
        
        isValidating = true
        errorMessage = ""
        
        Task {
            do {
                // Query Yahoo Finance chart API to validate the ticker exists and fetch initial price
                let priceData = try await priceService.fetchPrice(for: cleanTicker)
                
                await MainActor.run {
                    // Update cache price model
                    if let existingCache = cachedPrices.first(where: { $0.ticker == cleanTicker }) {
                        existingCache.price = priceData.price
                        existingCache.change24h = priceData.change24h
                        existingCache.lastUpdated = Date()
                    } else {
                        let newCache = StockPrice(ticker: cleanTicker, price: priceData.price, change24h: priceData.change24h)
                        modelContext.insert(newCache)
                    }
                    
                    // If position already exists, add to shares
                    if let existingPos = portfolio.positions.first(where: { $0.ticker == cleanTicker }) {
                        existingPos.shares += shares
                    } else {
                        let newPosition = Position(ticker: cleanTicker, shares: shares)
                        modelContext.insert(newPosition)
                        portfolio.positions.append(newPosition)
                    }
                    
                    try? modelContext.save()
                    isValidating = false
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    isValidating = false
                    errorMessage = "Failed to validate ticker. Check symbol and network connection."
                }
            }
        }
    }
}
