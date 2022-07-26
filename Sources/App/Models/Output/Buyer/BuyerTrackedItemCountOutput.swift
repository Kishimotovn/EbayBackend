import Foundation
import Vapor

struct BuyerTrackedItemCountOutput: Content {
    var receivedAtUSWarehouseCount: Int
    var flyingBackCount: Int
    var receivedAtVNWarehouseCount: Int
}
