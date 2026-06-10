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
    
    @State private var isCustomAsset = false
    @State private var customCurrency = "USD"
    
    private let priceService = StockPriceService()
    private let currencies = ["USD"] + AppGroupSettings.shared.supportedCurrencies
    
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
                    Picker("Asset Type", selection: $isCustomAsset) {
                        Text("Stock / ETF").tag(false)
                        Text("Custom Asset").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, 8)
                    
                    if !isCustomAsset {
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
                                                                .font(.caption2)
                                                                .fontWeight(.semibold)
                                                                .padding(.horizontal, 8)
                                                                .padding(.vertical, 4)
                                                                .background(
                                                                    LinearGradient(
                                                                        colors: [Color(hex: "#00F0FF").opacity(0.15), Color(hex: "#8A2BE2").opacity(0.15)],
                                                                        startPoint: .leading,
                                                                        endPoint: .trailing
                                                                    )
                                                                )
                                                                .cornerRadius(6)
                                                                .foregroundColor(Color(hex: "#00F0FF"))
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
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Asset Name")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .textCase(.uppercase)
                            
                            TextField("e.g. Apartment, Car, Art", text: $ticker)
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
                            Text("Currency")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .textCase(.uppercase)
                            
                            Menu {
                                ForEach(currencies, id: \.self) { cur in
                                    Button(action: {
                                        customCurrency = cur
                                    }) {
                                        Text("\(cur) (\(AppGroupSettings.shared.getSymbol(for: cur)))")
                                    }
                                }
                            } label: {
                                HStack {
                                    Text("\(customCurrency) (\(AppGroupSettings.shared.getSymbol(for: customCurrency)))")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Asset Value (\(customCurrency))")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .textCase(.uppercase)
                            
                            TextField("e.g. 1000000", text: $sharesText)
                                .keyboardType(.decimalPad)
                                .padding()
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(12)
                                .foregroundColor(.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        }
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
                            let btnLabel: String = {
                                if isValidating {
                                    return isCustomAsset ? (customCurrency == "USD" ? "Saving..." : "Validating Rate...") : "Validating Ticker..."
                                } else {
                                    return "Add Position"
                                }
                            }()
                            Text(btnLabel)
                                .font(.headline)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(LinearGradient(colors: [Color(hex: "#00F0FF"), Color(hex: "#8A2BE2")], startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(16)
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
                if isCustomAsset { return }
                
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
        if isCustomAsset {
            let cleanName = ticker.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanName.isEmpty else {
                errorMessage = "Please enter an asset name."
                return
            }
            
            let cleanValueText = sharesText.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: ",", with: ".")
            
            guard let value = Double(cleanValueText), value > 0 else {
                errorMessage = "Please enter a valid positive value."
                return
            }
            
            isValidating = true
            errorMessage = ""
            
            let currency = customCurrency.uppercased()
            if currency == "USD" {
                saveCustomPosition(name: cleanName, value: value, currency: currency)
            } else {
                let rateTicker = AppGroupSettings.shared.getExchangeRateTicker(for: currency)
                Task {
                    do {
                        let priceData = try await priceService.fetchPrice(for: rateTicker)
                        await MainActor.run {
                            if let existingCache = cachedPrices.first(where: { $0.ticker == rateTicker }) {
                                existingCache.price = priceData.price
                                existingCache.change24h = priceData.change24h
                                existingCache.lastUpdated = Date()
                            } else {
                                let newCache = StockPrice(ticker: rateTicker, price: priceData.price, change24h: priceData.change24h)
                                modelContext.insert(newCache)
                            }
                            saveCustomPosition(name: cleanName, value: value, currency: currency)
                        }
                    } catch {
                        await MainActor.run {
                            isValidating = false
                            errorMessage = "Failed to validate currency exchange rate for \(currency)."
                        }
                    }
                }
            }
        } else {
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
                    let priceData = try await priceService.fetchPrice(for: cleanTicker)
                    
                    await MainActor.run {
                        if let existingCache = cachedPrices.first(where: { $0.ticker == cleanTicker }) {
                            existingCache.price = priceData.price
                            existingCache.change24h = priceData.change24h
                            existingCache.lastUpdated = Date()
                        } else {
                            let newCache = StockPrice(ticker: cleanTicker, price: priceData.price, change24h: priceData.change24h)
                            modelContext.insert(newCache)
                        }
                        
                        if let existingPos = portfolio.positions.first(where: { $0.ticker == cleanTicker && !$0.isCustomAsset }) {
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
    
    private func saveCustomPosition(name: String, value: Double, currency: String) {
        if let existingPos = portfolio.positions.first(where: { $0.ticker.uppercased() == name.uppercased() && $0.isCustomAsset && $0.customCurrency == currency }) {
            existingPos.shares += value
        } else {
            let newPosition = Position(ticker: name, shares: value, isCustomAsset: true, customCurrency: currency)
            modelContext.insert(newPosition)
            portfolio.positions.append(newPosition)
        }
        
        try? modelContext.save()
        isValidating = false
        isPresented = false
    }
}
