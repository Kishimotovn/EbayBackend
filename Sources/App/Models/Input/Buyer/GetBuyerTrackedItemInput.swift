import Foundation
import Vapor

struct GetBuyerTrackedItemInput: Content, @unchecked Sendable {
    var filteredStates: [TrackedItem.State]
    var searchString: String?
    @OptionalISO8601Date var fromDate: Date?
    @OptionalISO8601Date var toDate: Date?
}
