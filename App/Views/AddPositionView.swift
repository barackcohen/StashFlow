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
    
    private let priceService = StockPriceService()
    
    public init(portfolio: Portfolio, isPresented: Binding<Bool>) {
        self.portfolio = portfolio
        self._isPresented = isPresented
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ticker Symbol")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .textCase(.uppercase)
                        
                        TextField("e.g. AAPL, TSLA, MSFT", text: $ticker)
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
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Number of Shares")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .textCase(.uppercase)
                        
                        TextField("e.g. 10 or 2.5", text: $sharesText)
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
        }
    }
    
    private func validateAndSavePosition() {
        let cleanTicker = ticker.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTicker.isEmpty else { return }
        
        guard let shares = Double(sharesText), shares > 0 else {
            errorMessage = "Please enter a valid positive number of shares."
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
