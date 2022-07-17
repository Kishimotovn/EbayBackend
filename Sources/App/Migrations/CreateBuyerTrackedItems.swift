import Foundation
import Vapor
import Fluent
import SQLKit

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
            .flatMap {
                guard let sqlDB = database as? SQLDatabase else {
                    return database.eventLoop.future()
                }
                
                return sqlDB.raw("""
                CREATE INDEX btn_index ON buyer_tracked_items USING gin (tracking_number gin_trgm_ops);
                """).run()
            }
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(BuyerTrackedItem.schema).delete()
    }
}
