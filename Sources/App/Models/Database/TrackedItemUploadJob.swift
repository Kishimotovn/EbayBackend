import Foundation
import Vapor
import Fluent

final class TrackedItemUploadJob: Model, @unchecked Sendable, Content {
    static let schema: String = "tracked_item_upload_jobs"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "file_id")
    var fileID: String

    @Field(key: "file_name")
    var fileName: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    struct TotalByDate: Content, @unchecked Sendable {
        @ISO8601Date var date: Date
        var total: Int

        init(date: Date, total: Int) {
            self._date = .init(date: date)
            self.total = total
        }
    }

    @Field(key: "totals")
    var totals: [TotalByDate]

    @Field(key: "state")
    var state: TrackedItem.State

    enum State: String, Codable {
        case pending
        case running
        case error
        case finished
    }

    @Field(key: "job_state")
    var jobState: State

    @Parent(key: "seller_id")
    var seller: Seller

    @OptionalField(key: "error")
    var error: String?

    @OptionalField(key: "import_id")
    var importID: String?

    init() { }
    
    init(
        fileID: String,
        jobState: State,
        fileName: String,
        state: TrackedItem.State,
        sellerID: Seller.IDValue
    ) {
        self.fileID = fileID
        self.fileName = fileName
        self.jobState = jobState
        self.totals = []
        self.state = state
        self.$seller.id = sellerID
    }
}

extension TrackedItemUploadJob: Parameter { }
