import Foundation
import Vapor
import Fluent
import FluentPostgresDriver

struct CreateBuyerTrackedItemLinkingView: AsyncMigration {
    func prepare(on database: Database) async throws {
        guard let sqlDB = database as? PostgresDatabase else {
            return
        }

        try await sqlDB.simpleQuery("""
        CREATE MATERIALIZED VIEW "\(BuyerTrackedItemLinkView.schema)"
        AS
        select gen_random_uuid () as "id", bti.id as "buyer_tracked_item_id", bti.tracking_number as "buyer_tracking_number", ti.id as "tracked_item_id", ti.tracking_number as "tracked_item_tracking_number"
        from buyer_tracked_items bti
        left join tracked_items ti
        on ti.tracking_number ILIKE concat('%', bti.tracking_number);
        """).get()

        try await sqlDB.simpleQuery("""
        CREATE UNIQUE INDEX ON buyer_tracked_item_link_view (id);
        """).get()
    }

    func revert(on database: Database) async throws {
        guard let sqlDB = database as? PostgresDatabase else {
            return
        }
        
        try await sqlDB.simpleQuery("""
        DROP MATERIALIZED VIEW "\(BuyerTrackedItemLinkView.schema)";
        """).get()
    }
}
