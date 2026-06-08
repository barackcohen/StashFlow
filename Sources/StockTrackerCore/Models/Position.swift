import Foundation
import SwiftData

@Model
public final class Position {
    @Attribute(.unique) public var id: UUID
    public var ticker: String
    public var shares: Double
    public var portfolio: Portfolio?
    
    public init(id: UUID = UUID(), ticker: String, shares: Double) {
        self.id = id
        self.ticker = ticker.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.shares = shares
    }
}
