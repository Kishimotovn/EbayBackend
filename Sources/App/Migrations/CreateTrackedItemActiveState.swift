import Foundation
import Vapor
import FluentKit
import SQLKit

struct CreateTrackedItemActiveState: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await (database as? SQLDatabase)?.raw("""
        CREATE VIEW "\(TrackedItemActiveState.schema)"
        AS
        with ranked_tracked_items as (
            SELECT
                ti.id, ti.tracking_number,
                trails.value->>'state' as "state", trails.value->>'updatedAt' as "state_updated_at",
                ROW_NUMBER() OVER (PARTITION BY "tracking_number" ORDER BY trails.value->>'updatedAt' DESC) AS rn
            from tracked_items ti
            left join jsonb_array_elements(to_jsonb(ti.state_trails)) trails on true
        )
        select *
        from ranked_tracked_items
        where rn = 1;
        """).run()
    }

    func revert(on database: Database) async throws {
        try await (database as? SQLDatabase)?.raw("""
        DROP VIEW "\(TrackedItemActiveState.schema)"
        """).run()
    }
}
