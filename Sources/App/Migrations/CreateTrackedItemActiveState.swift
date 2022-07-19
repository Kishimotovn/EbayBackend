import Foundation
import Vapor
import FluentKit
import SQLKit

struct CreateTrackedItemActiveState: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await (database as? SQLDatabase)?.raw("""
        CREATE MATERIALIZED VIEW "\(raw: TrackedItemActiveState.schema)"
        AS
        with ranked_tracked_items as (
            SELECT
                ti.id,
                ti.tracking_number,
                trails.value->>'state' as "state", trails.value->>'updatedAt' as "state_updated_at",
                ROW_NUMBER() OVER (PARTITION BY "tracking_number", trails.value->>'state' ORDER BY trails.value->>'updatedAt' DESC) AS rn
            from tracked_items ti
            left join jsonb_array_elements(to_jsonb(ti.state_trails)) trails on true
        ),
        ungrouped as (
            select *,
                case
                    when state = 'flyingBack' then state_updated_at
                end as "flying_back_updated_at",
                case
                    when state = 'receivedAtUSWarehouse' then state_updated_at
                end as "received_at_us_updated_at",
                case
                    when state = 'receivedAtVNWarehouse' then state_updated_at
                end as "received_at_vn_updated_at"
            from ranked_tracked_items
            where rn = 1
        ),
        ranked as (
        select
            ungrouped.id, ungrouped.tracking_number, ungrouped.state, ungrouped.state_updated_at,
            max("flying_back_updated_at") over (partition by tracking_number) as "flying_back_updated_at",
            max("received_at_us_updated_at") over (partition by tracking_number) as "received_at_us_updated_at",
            max("received_at_vn_updated_at") over (partition by tracking_number) as "received_at_vn_updated_at",
            ROW_NUMBER() OVER (PARTITION BY "tracking_number" ORDER BY state_updated_at DESC) AS rn
            from ungrouped
        )
        select
            *,
            case
                when state = 'receivedAtUSWarehouse' then 1
                when state = 'flyingBack' then 2
                when state = 'receivedAtVNWarehouse' then 3
                else 4
            end as power
        from ranked
        where rn = 1;
        """).run()
        
        try await (database as? SQLDatabase)?.raw("""
        CREATE UNIQUE INDEX ON \(raw: TrackedItemActiveState.schema) (id);
        """).run()
    }

    func revert(on database: Database) async throws {
        try await (database as? SQLDatabase)?.raw("""
        DROP MATERIALIZED VIEW "\(raw: TrackedItemActiveState.schema)"
        """).run()
    }
}
