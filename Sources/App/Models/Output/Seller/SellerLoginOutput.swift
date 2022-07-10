import Foundation
import Vapor

struct SellerLoginOutput: Content {
    var refreshToken: String
    var accessToken: String
    var expiredAt: Date
    var seller: SellerOutput

    init(refreshToken: String, accessToken: String, expiredAt: Date, seller: SellerOutput) {
        self.refreshToken = refreshToken
        self.accessToken = accessToken
        self.expiredAt = expiredAt
        self.seller = seller
    }
}
