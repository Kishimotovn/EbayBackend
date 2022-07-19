import Vapor
import Foundation

struct GetBuyerTrackedItemPageOutput: Content {
    struct Metadata: Content {
        var page: Int
        var per: Int
        var total: Int
        var pageCount: Int
        var searchString: String?
        var filteredStates: [TrackedItem.State]
        @OptionalISO8601Date var fromDate: Date?
        @OptionalISO8601Date var toDate: Date?

        init(page: Int, per: Int, total: Int, pageCount: Int, searchString: String?, filteredStates: [TrackedItem.State], fromDate: Date?, toDate: Date?) {
            self.page = page
            self.per = per
            self.total = total
            self.pageCount = pageCount
            self.searchString = searchString
            self.filteredStates = filteredStates
            self._fromDate = .init(date: fromDate)
            self._toDate = .init(date: toDate)
        }
    }

    var items: [BuyerTrackedItemOutput]
    var metadata: Metadata
}
