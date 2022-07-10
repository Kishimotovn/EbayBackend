import Foundation
import Vapor

struct BuyerOutput: Content {
    var id: Buyer.IDValue?
    var username: String
    var email: String
    var phoneNumber: String
    var createdAt: Date?
    var updatedAt: Date?
    var verifiedAt: Date?
}

extension Buyer: HasOutput {
    func output() -> BuyerOutput {
        .init(
            id: self.id,
            username: self.username,
            email: self.email,
            phoneNumber: self.phoneNumber,
            createdAt: self.createdAt,
            updatedAt: self.updatedAt,
            verifiedAt: self.verifiedAt
        )
    }
}
