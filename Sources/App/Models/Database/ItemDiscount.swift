//
//  File.swift
//  
//
//  Created by Phan Tran on 23/05/2020.
//

import Foundation
import Vapor
import Fluent

final class ItemDiscount: Model, @unchecked Sendable, Content {
    static let schema: String = "item_discounts"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "amount")
    var amount: Int

    enum DiscountType: String, Codable {
        case percentage
        case direct
    }

    @Enum<DiscountType>(key: "discount_type")
    var discountType: DiscountType

    @Parent(key: "item_id")
    var item: Item

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() { }

    init(itemID: Item.IDValue, amount: Int, discountType: DiscountType) {
        self.$item.id = itemID
        self.amount = amount
        self.discountType = discountType
    }
}
