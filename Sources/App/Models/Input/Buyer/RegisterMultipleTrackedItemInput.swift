import Foundation
import Vapor

struct RegisterMultipleTrackedItemInput: Content {
    var trackedItemIDs: [TrackedItem.IDValue]
    var sharedNote: String?
}
