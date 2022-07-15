import Foundation
import Vapor

struct RegisterMultipleTrackedItemInput: Content {
    var trackingNumbers: [String]
    var sharedNote: String?
}
