import Vapor
import Foundation

struct TrackedItemOutput: Content {
    var id: TrackedItem.IDValue?
    var createdAt: Date?
    var updatedAt: Date?
    var trackingNumber: String
    var stateTrails: [TrackedItem.StateTrail]
}

extension TrackedItem {
    func output() -> TrackedItemOutput {
        return .init(
            id: self.id,
            createdAt: self.createdAt,
            updatedAt: self.updatedAt,
            trackingNumber: self.trackingNumber,
            stateTrails: self.stateTrails
        )
    }
}
