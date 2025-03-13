import Foundation
import Vapor
import FluentKit

final class TrackedItemActiveState: Model, @unchecked Sendable {
    static let schema: String = "tracked_items_active_state"
    @ID(key: .id)
    var id: UUID?

    @Field(key: "tracking_number")
    var trackingNumber: String

    @Field(key: "state")
    var state: TrackedItem.State

    @Field(key: "state_updated_at")
    var stateUpdatedAt: Date

    @Field(key: "power")
    var power: Int

    @OptionalField(key: "received_at_us_updated_at")
    var receivedAtUSAt: Date?
    
    @OptionalField(key: "flying_back_updated_at")
    var flyingBackAt: Date?

    @OptionalField(key: "received_at_vn_updated_at")
    var receivedAtVNAt: Date?

    init() { }
}
