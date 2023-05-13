import Foundation
import Vapor

struct FaultyTrackingItemNotificationInput: Content {
    var trackingNumber: String
    var faultDescription: String
    var receivedAtUSAt: Date
}
