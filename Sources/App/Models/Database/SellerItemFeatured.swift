//
//  File.swift
//  
//
//  Created by Phan Tran on 18/09/2020.
//

import Foundation
import Vapor
import Fluent

final class SellerItemFeatured: Model, Content {
    static var schema: String = "seller_item_featured"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "seller_id")
    var seller: Seller

    @Parent(key: "item_id")
    var item: Item

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?

    @Field(key: "volumeDiscounts")
    var volumeDiscounts: [VolumeDiscount]?

    @OptionalField(key: "further_discount_amount")
    var furtherDiscountAmount: Int?

    @Field(key: "further_discount_detected")
    var furtherDiscountDetected: Bool

    @OptionalField(key: "item_end_date")
    var itemEndDate: Date?

    init() { }

    init(sellerID: Seller.IDValue,
         itemID: Item.IDValue,
         volumeDiscounts: [VolumeDiscount]?,
         furtherDiscountAmount: Int?,
         furtherDiscountDetected: Bool,
         itemEndDate: Date?) {
        self.$seller.id = sellerID
        self.$item.id = itemID
        self.volumeDiscounts = volumeDiscounts
        self.furtherDiscountAmount = furtherDiscountAmount
        self.furtherDiscountDetected = furtherDiscountDetected
        self.itemEndDate = itemEndDate
    }
}

extension SellerItemFeatured: Parameter { }
