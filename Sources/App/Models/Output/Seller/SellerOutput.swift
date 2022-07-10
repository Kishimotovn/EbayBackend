import Foundation
import Vapor

struct SellerOutput: Content {
    var id: Seller.IDValue?
    var name: String
    var createdAt: Date?
    var updatedAt: Date?
}

extension Seller: HasOutput {
    func output() -> SellerOutput {
        .init(
            id: self.id,
            name: self.name,
            createdAt: self.createdAt,
            updatedAt: self.updatedAt
        )
    }
}
