import Foundation
import SwiftData

@Model
public final class Position {
    @Attribute(.unique) public var id: UUID
    public var ticker: String
    public var shares: Double
    public var isCustomAssetNullable: Bool?
    public var customCurrency: String?
    public var portfolio: Portfolio?
    
    public var isCustomAsset: Bool {
        get { isCustomAssetNullable ?? false }
        set { isCustomAssetNullable = newValue }
    }
    
    public init(id: UUID = UUID(), ticker: String, shares: Double, isCustomAsset: Bool = false, customCurrency: String? = nil) {
        self.id = id
        self.ticker = isCustomAsset ? ticker.trimmingCharacters(in: .whitespacesAndNewlines) : ticker.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.shares = shares
        self.isCustomAssetNullable = isCustomAsset
        self.customCurrency = customCurrency
    }
}
