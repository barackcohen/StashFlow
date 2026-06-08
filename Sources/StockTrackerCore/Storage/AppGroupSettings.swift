import Foundation

public final class AppGroupSettings: Sendable {
    public static let shared = AppGroupSettings()
    
    private let suite: UserDefaults?
    
    public let supportedCurrencies = ["EUR", "GBP", "CAD", "ILS", "JPY", "AUD", "CHF"]
    
    private init() {
        self.suite = UserDefaults(suiteName: "group.com.barackcohen.myportfolios")
    }
    
    public var selectedSecondaryCurrency: String {
        get {
            suite?.string(forKey: "selectedSecondaryCurrency") ?? "EUR"
        }
        set {
            suite?.set(newValue, forKey: "selectedSecondaryCurrency")
        }
    }
    
    public var username: String {
        get {
            suite?.string(forKey: "username") ?? "Sarah"
        }
        set {
            suite?.set(newValue, forKey: "username")
        }
    }
    
    /// Converts a currency code to its symbol.
    public func getSymbol(for currency: String) -> String {
        switch currency.uppercased() {
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "CAD": return "C$"
        case "ILS": return "₪"
        case "JPY": return "¥"
        case "AUD": return "A$"
        case "CHF": return "CHF"
        default: return currency
        }
    }
    
    /// Returns the Yahoo Finance ticker symbol for the currency pair exchange rate.
    /// E.g., "USDEUR=X" for USD to EUR.
    public func getExchangeRateTicker(for currency: String) -> String {
        return "USD\(currency.uppercased())=X"
    }
}
