import Foundation
import Vapor
import Fluent

struct CreateTrackedItemUploadJobs: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(TrackedItemUploadJob.schema)
            .id()
            .field("file_id", .string, .required)
            .field("file_name", .string, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .field("totals", .array(of: .json), .required)
            .field("job_state", .string, .required)
            .field("state", .string, .required)
            .field("seller_id", .uuid, .required, .references(Seller.schema, "id"))
            .field("error", .string)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(TrackedItemUploadJob.schema)
            .delete()
    }
}
