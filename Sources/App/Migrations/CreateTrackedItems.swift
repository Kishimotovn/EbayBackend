import Foundation
import Vapor
import Fluent
import SQLKit

struct CreateTrackedItems: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(TrackedItem.schema)
            .id()
            .field("seller_id", .uuid, .references(Seller.schema, "id"))
            .field("seller_note", .string, .required)
            .field("tracking_number", .string, .required)
            .field("state_trails", .array(of: .json), .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "tracking_number", "seller_id")
            .create()
            .flatMap { _ in
                guard let sqlDB = database as? SQLDatabase else {
                    return database.eventLoop.future()
                }
                
                return sqlDB.raw("""
                CREATE EXTENSION pg_trgm;
                """).run()
            }.flatMap {
                guard let sqlDB = database as? SQLDatabase else {
                    return database.eventLoop.future()
                }
                
                return sqlDB.raw("""
                CREATE INDEX trgm_idx ON tracked_items USING gin (tracking_number gin_trgm_ops);
                """).run()
            }
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(TrackedItem.schema).delete()
    }
}
