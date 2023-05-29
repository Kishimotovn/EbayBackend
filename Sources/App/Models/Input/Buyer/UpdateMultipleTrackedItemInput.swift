import Foundation
import Vapor

struct UpdateMultipleTrackedItemsInput: Content {
    var trackedItemIDs: [BuyerTrackedItem.IDValue]
    var sharedNote: String
	var sharedPackingRequest: String
}
