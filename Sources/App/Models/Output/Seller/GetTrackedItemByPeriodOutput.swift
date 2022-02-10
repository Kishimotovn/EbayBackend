import Foundation
import Vapor

struct GetTrackedItemByPeriodOutput: Content {
    @OptionalISO8601Date var fromDate: Date?
    @OptionalISO8601Date var toDate: Date?
    var searchString: String?

    var itemsByDate: [
        String: [TrackedItem]
    ]

    init(fromDate: Date?, toDate: Date?, items: [TrackedItem]) {
        self._fromDate = .init(date: fromDate)
        self._toDate = .init(date: toDate)
        self.itemsByDate = Dictionary.init(grouping: items) { item in
            let createdAt = item.createdAt ?? Date()
            return createdAt.toISODate()
        }
    }
}
