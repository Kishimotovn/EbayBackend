import Foundation
import Vapor
import Fluent

final class BuyerTrackedItemLinkView: Model, @unchecked Sendable, Content {
    static let schema: String = "buyer_tracked_item_link_view"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "buyer_tracked_item_id")
    var buyerTrackedItem: BuyerTrackedItem

    @Parent(key: "tracked_item_id")
    var trackedItem: TrackedItem

    @Field(key: "buyer_tracking_number")
    var buyerTrackingNumber: String

    @Field(key: "tracked_item_tracking_number")
    var trackedItemTrackingNumber: String

    init() { }
}
