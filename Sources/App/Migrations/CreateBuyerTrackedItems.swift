import Foundation
import Vapor
import Fluent

struct CreateBuyerTrackedItems: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(BuyerTrackedItem.schema)
            .id()
            .field("note", .string, .required, .sql(raw: "DEFAULT ''"))
            .field("buyer_id", .uuid, .required, .references(Buyer.schema, "id"))
            .field("tracking_number", .string, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(BuyerTrackedItem.schema).delete()
    }
}
