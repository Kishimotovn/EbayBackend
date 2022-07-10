import Foundation
import Vapor

struct BuyerLoginOutput: Content {
    var refreshToken: String
    var accessToken: String
    var expiredAt: Date
    var buyer: BuyerOutput

    init(refreshToken: String, accessToken: String, expiredAt: Date, buyer: BuyerOutput) {
        self.refreshToken = refreshToken
        self.accessToken = accessToken
        self.expiredAt = expiredAt
        self.buyer = buyer
    }
}
