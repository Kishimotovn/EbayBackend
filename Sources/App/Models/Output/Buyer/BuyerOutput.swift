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
	var packingRequestLeft: Int?
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
            verifiedAt: self.verifiedAt,
			packingRequestLeft: self.packingRequestLeft
        )
    }
}

struct BuyerDCOutput: Content {
    var id: Buyer.IDValue?
    var username: String
    var passwordHash: String
    var email: String
    var phoneNumber: String
    var createdAt: Date?
    var updatedAt: Date?
    var deletedAt: Date?
    var verifiedAt: Date?
    var packingRequestLeft: Int?
}

extension Buyer {
    func dcOutput() -> BuyerDCOutput {
        .init(
            id: self.id,
            username: self.username,
            passwordHash: self.passwordHash,
            email: self.email,
            phoneNumber: self.phoneNumber,
            createdAt: self.createdAt,
            updatedAt: self.updatedAt,
            deletedAt: self.deletedAt,
            verifiedAt: self.verifiedAt,
            packingRequestLeft: self.packingRequestLeft
        )
    }
}
