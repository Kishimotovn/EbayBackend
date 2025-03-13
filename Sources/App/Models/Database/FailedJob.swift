import Foundation
import Vapor
import Fluent

final class FailedJob: Model, @unchecked Sendable, Content {
    static let schema: String = "failed_jobs"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "payload")
    var payload: Data

    @Field(key: "job_identifier")
    var jobIdentifier: String

    @Field(key: "error")
    var error: String

    @OptionalField(key: "tracking_number")
    var trackingNumber: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() { }

    init(payload: Data, jobIdentifier: String, error: String, trackingNumber: String?) {
        self.jobIdentifier = jobIdentifier
        self.payload = payload
        self.error = error
        self.trackingNumber = trackingNumber
    }
}
