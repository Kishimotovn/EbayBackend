import Foundation
import Vapor
struct ProductBrokenInput: Content {
    var trackingNumber: String
    var description: String
    var receivedAtUSAt: Date
}