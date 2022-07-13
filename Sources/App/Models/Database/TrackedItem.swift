import Vapor
import Fluent
import Foundation

final class TrackedItem: Model, Content {
    static var schema: String = "tracked_items"

    @ID(key: .id)
    var id: UUID?

    @OptionalParent(key: "seller_id")
    var seller: Seller?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Field(key: "tracking_number")
    var trackingNumber: String

    @Field(key: "seller_note")
    var sellerNote: String

    @Field(key: "import_ids")
    var importIDs: [String]

    enum State: String, Codable, CaseIterable {
        case receivedAtUSWarehouse
        case flyingBack
        case receivedAtVNWarehouse
        case delivered
    }

    @Field(key: "state_trails")
    var stateTrails: [StateTrail]

    struct StateTrail: Content {
        var state: State
        @ISO8601DateTime var updatedAt: Date
        var importID: String?

        init(state: State, updatedAt: Date = Date(), importID: String?) {
            self.state = state
            self._updatedAt = .init(date: updatedAt)
            self.importID = importID
        }
    }

    @Children(for: \.$trackedItem)
    var buyerTrackedItems: [BuyerTrackedItem]

    init() {}

    init(
        sellerID: Seller.IDValue?,
        trackingNumber: String,
        stateTrails: [StateTrail],
        sellerNote: String,
        importIDs: [String]
    ) {
        self.$seller.id = sellerID
        self.trackingNumber = trackingNumber
        self.stateTrails = stateTrails
        self.sellerNote = sellerNote
        self.importIDs = importIDs
    }
}

extension TrackedItem {
    var state: State? {
        return self.stateTrails.sorted { lhs, rhs in
            return lhs.updatedAt.compare(rhs.updatedAt) == .orderedDescending
        }.first?.state
    }
}

extension TrackedItem: Parameter { }
