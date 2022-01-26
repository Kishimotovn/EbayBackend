import Foundation
import Vapor
import Fluent

struct CreateTrackedItems: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(TrackedItem.schema)
            .id()
            .field("seller_id", .uuid, .references(Seller.schema, "id"))
            .field("seller_note", .string, .required)
            .field("tracking_number", .string, .required)
            .field("state", .string, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "tracking_number", "seller_id")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(TrackedItem.schema).delete()
    }
}
