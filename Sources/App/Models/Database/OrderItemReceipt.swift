//
//  File.swift
//  
//
//  Created by Phan Tran on 23/05/2020.
//

import Foundation
import Vapor
import Fluent

final class OrderItemReceipt: Model, @unchecked Sendable, Content {
    static let schema: String = "order_item_receipts"
    
    @ID(key: .id)
    var id: UUID?

    @Parent(key: "order_item_id")
    var orderItem: OrderItem

    @Field(key: "image_url")
    var imageURL: String

    @OptionalField(key: "tracking_number")
    var trackingNumber: String?

    @Field(key: "resolved_quantity")
    var resolvedQuantity: Int

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() { }

    init(orderItemID: OrderItem.IDValue, imageURL: String, trackingNumber: String?, resolvedQuantity: Int) {
        self.$orderItem.id = orderItemID
        self.imageURL = imageURL
        self.trackingNumber = trackingNumber
        self.resolvedQuantity = resolvedQuantity
    }
}

extension OrderItemReceipt: Parameter { }
