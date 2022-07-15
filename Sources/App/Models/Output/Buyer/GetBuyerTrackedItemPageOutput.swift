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
    }

    var items: [BuyerTrackedItemOutput]
    var metadata: Metadata
}
