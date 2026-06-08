import Foundation
import SwiftData

@Model
public final class Portfolio {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var hexColor: String
    
    @Relationship(deleteRule: .cascade, inverse: \Position.portfolio)
    public var positions: [Position] = []
    
    public init(id: UUID = UUID(), name: String, hexColor: String = "#00F0FF") {
        self.id = id
        self.name = name
        self.hexColor = hexColor
    }
}
