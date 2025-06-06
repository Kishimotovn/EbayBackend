import Vapor
import Fluent
import Foundation

final class TrackedItem: Model, @unchecked Sendable, Content {
    static let schema: String = "tracked_items"

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
		case registered

        var power: Int {
            switch self {
			case .registered:
				return 0
            case .receivedAtUSWarehouse:
                return 1
            case .flyingBack:
                return 2
            case .receivedAtVNWarehouse:
                return 3
            case .delivered:
                return 4
            }
			
        }
    }

    @Field(key: "state_trails")
    var stateTrails: [StateTrail]

    struct StateTrail: Content, @unchecked Sendable {
        var state: State
        @ISO8601DateTime var updatedAt: Date
        var importID: String?

        init(state: State, updatedAt: Date = Date(), importID: String?) {
            self.state = state
            self._updatedAt = .init(date: updatedAt)
            self.importID = importID
        }
    }

//    @Children(for: \.$trackedItem)
//    var buyerTrackedItems: [BuyerTrackedItem]

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

extension TrackedItem {
    func new() -> TrackedItem {
        let newTrackedItem = TrackedItem(
            sellerID: self.$seller.id,
            trackingNumber: self.trackingNumber,
            stateTrails: self.stateTrails,
            sellerNote: self.sellerNote,
            importIDs: self.importIDs
        )
        newTrackedItem.createdAt = self.createdAt
        return newTrackedItem
    }
}
