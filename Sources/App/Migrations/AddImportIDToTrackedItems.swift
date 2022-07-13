import Foundation
import Vapor
import FluentKit

struct AddImportIDsToTrackedItems: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(TrackedItem.schema)
            .field("import_ids", .array(of: .string), .required, .sql(raw: "DEFAULT array[]::text[]"))
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema(TrackedItem.schema)
            .deleteField("import_ids")
            .update()
    }
}
