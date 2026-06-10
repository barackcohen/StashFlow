import Foundation
import SwiftData

@Model
public final class Position {
    @Attribute(.unique) public var id: UUID
    public var ticker: String
    public var shares: Double
    public var isCustomAsset: Bool
    public var customCurrency: String?
    public var portfolio: Portfolio?
    
    public init(id: UUID = UUID(), ticker: String, shares: Double, isCustomAsset: Bool = false, customCurrency: String? = nil) {
        self.id = id
        self.ticker = isCustomAsset ? ticker.trimmingCharacters(in: .whitespacesAndNewlines) : ticker.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.shares = shares
        self.isCustomAsset = isCustomAsset
        self.customCurrency = customCurrency
    }
}
