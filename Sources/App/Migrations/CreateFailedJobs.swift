import Foundation
import Fluent

struct CreateFailedJobs: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(FailedJob.schema)
            .id()
            .field("payload", .data, .required)
            .field("job_identifier", .string, .required)
            .field("created_at", .datetime)
            .field("error", .string, .required)
            .field("tracking_number", .string)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(FailedJob.schema)
            .delete()
    }
}
