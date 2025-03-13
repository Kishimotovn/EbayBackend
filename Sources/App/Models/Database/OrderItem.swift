//
//  OrderItem.swift
//  
//
//  Created by Phan Tran on 23/05/2020.
//

import Foundation
import Vapor
import Fluent

final class OrderItem: Model, @unchecked Sendable, Content {
    static let parameter = "order_item_id"
    static let schema: String = "order_item"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "order_id")
    var order: Order

    @Parent(key: "item_id")
    var item: Item

    @Field(key: "index")
    var index: Int

    @Field(key: "accepted_price")
    var acceptedPrice: Int

    @Field(key: "updated_price")
    var updatedPrice: Int?

    @Field(key: "quantity")
    var quantity: Int

    @Field(key: "is_processed")
    var isProcessed: Bool

    @OptionalField(key: "further_discount_amount")
    var furtherDiscountAmount: Int?

    @Field(key: "further_discount_detected")
    var furtherDiscountDetected: Bool

    @Children(for: \.$orderItem)
    var receipts: [OrderItemReceipt]

    @Field(key: "volumeDiscounts")
    var volumeDiscounts: [VolumeDiscount]?

    @Field(key: "is_from_featured")
    var isFromFeatured: Bool

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @OptionalField(key: "item_end_date")
    var itemEndDate: Date?

    init() {}

    init(orderID: Order.IDValue,
         itemID: Item.IDValue,
         index: Int, quantity: Int,
         itemEndDate: Date? = nil,
         furtherDiscountAmount: Int? = nil,
         isProcessed: Bool = false,
         furtherDiscountDetected: Bool = false,
         isFromFeatured: Bool = false) {
        self.$order.id = orderID
        self.$item.id = itemID
        self.index = index
        self.quantity = quantity
        self.itemEndDate = itemEndDate
        self.furtherDiscountAmount = furtherDiscountAmount
        self.isProcessed = isProcessed
        self.furtherDiscountDetected = furtherDiscountDetected
        self.isFromFeatured = isFromFeatured
    }
}

extension OrderItem: Parameter { }
