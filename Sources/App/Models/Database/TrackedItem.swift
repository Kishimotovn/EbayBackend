import Vapor
import Fluent

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

    enum State: String, Codable {
        case registered
        case receivedAtWarehouse
    }

    @Field(key: "state")
    var state: State

    init() {}

    init(
        sellerID: Seller.IDValue?,
        trackingNumber: String,
        state: State,
        sellerNote: String
    ) {
        self.$seller.id = sellerID
        self.trackingNumber = trackingNumber
        self.state = state
        self.sellerNote = sellerNote
    }
}

extension TrackedItem: Parameter { }
