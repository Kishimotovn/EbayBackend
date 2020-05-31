//
//  OrderItem.swift
//  
//
//  Created by Phan Tran on 23/05/2020.
//

import Foundation
import Fluent

final class OrderItem: Model {
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

    @Field(key: "quantity")
    var quantity: Int

    @Children(for: \.$orderItem)
    var receipts: [OrderItemReceipt]

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() {}

    init(orderID: Order.IDValue, itemID: Item.IDValue, index: Int, quantity: Int) {
        self.$order.id = orderID
        self.$item.id = itemID
        self.index = index
        self.quantity = quantity
    }
}

extension OrderItem: Parameter { }
