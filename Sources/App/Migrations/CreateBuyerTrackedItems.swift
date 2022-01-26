import Foundation
import Vapor
import Fluent

struct CreateBuyerTrackedItems: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(BuyerTrackedItem.schema)
            .id()
            .field("note", .string, .required, .sql(raw: "DEFAULT ''"))
            .field("buyer_id", .uuid, .required, .references(Buyer.schema, "id"))
            .field("tracked_item_id", .uuid, .required, .references(TrackedItem.schema, "id"))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "buyer_id", "tracked_item_id")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(BuyerTrackedItem.schema).delete()
    }
}
