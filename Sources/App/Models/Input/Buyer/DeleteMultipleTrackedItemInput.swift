import Foundation
import Vapor

struct DeleteMultipleTrackedItemsInput: Content {
    var trackedItemIDs: [BuyerTrackedItem.IDValue]
}
