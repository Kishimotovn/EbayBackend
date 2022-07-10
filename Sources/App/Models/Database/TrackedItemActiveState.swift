import Foundation
import Vapor
import FluentKit

final class TrackedItemActiveState: Model {
    static var schema: String = "tracked_items_active_state"
    @ID(key: .id)
    var id: UUID?

    @Field(key: "tracking_number")
    var trackingNumber: String

    @Field(key: "state")
    var state: TrackedItem.State

    @Field(key: "state_updated_at")
    var stateUpdatedAt: Date

    init() { }
}
