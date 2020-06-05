//
//  Order.swift
//  
//
//  Created by Phan Tran on 23/05/2020.
//

import Foundation
import Vapor
import Fluent

final class Order: Model, Content {
    static let schema = "orders"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "order_index")
    var orderIndex: Int

    @Parent(key: "buyer_id")
    var buyer: Buyer

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?

    @Siblings(through: OrderItem.self, from: \.$order, to: \.$item)
    var items: [Item]

    @Children(for: \.$order)
    var orderItems: [OrderItem]

    @OptionalParent(key: "warehouse_address_id")
    var warehouseAddress: WarehouseAddress?

    @OptionalField(key: "order_registered_at")
    var orderRegisteredAt: Date?

    @OptionalParent(key: "order_option_id")
    var orderOption: OrderOption?

    @OptionalParent(key: "seller_id")
    var seller: Seller?

    enum State: String, Codable {
        case cart
        case registered
        case inProgress
        case waitingForTracking
        case delivered

        case stuck
        case failed
    }

    @Enum<State>(key: "state")
    var state: State

    init() { }

    init(id: UUID? = nil, state: State = .cart, buyerID: Buyer.IDValue) {
        self.id = id
        self.orderIndex = -1
        self.state = state
        self.$buyer.id = buyerID
    }
}

extension Order: Parameter { }
