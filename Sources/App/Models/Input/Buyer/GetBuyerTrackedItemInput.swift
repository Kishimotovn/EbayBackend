import Foundation
import Vapor

struct GetBuyerTrackedItemInput: Content {
    var filteredStates: [TrackedItem.State]
    var searchString: String?
}
