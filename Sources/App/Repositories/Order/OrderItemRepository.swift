//
//  File.swift
//  
//
//  Created by Phan Tran on 25/05/2020.
//

import Foundation
import Vapor
import Fluent

protocol OrderItemRepository {
    func find(itemID: Item.IDValue, orderID: Order.IDValue) -> EventLoopFuture<OrderItem?>
    func save(orderItem: OrderItem) -> EventLoopFuture<Void>
    func delete(orderItem: OrderItem) -> EventLoopFuture<Void>
    func find(orderID: Order.IDValue,
              orderItemID: OrderItem.IDValue) -> EventLoopFuture<OrderItem?>
}

struct DatabaseOrderItemRepository: OrderItemRepository {
    let db: Database

    func find(orderID: Order.IDValue, orderItemID: OrderItem.IDValue) -> EventLoopFuture<OrderItem?> {
        return OrderItem.query(on: self.db)
            .filter(\.$id == orderItemID)
            .filter(\.$order.$id == orderID)
            .first()
    }

    func save(orderItem: OrderItem) -> EventLoopFuture<Void> {
        return orderItem.save(on: self.db)
    }

    func delete(orderItem: OrderItem) -> EventLoopFuture<Void> {
        return orderItem.delete(on: self.db)
    }

    func find(itemID: Item.IDValue, orderID: Order.IDValue) -> EventLoopFuture<OrderItem?> {
        return OrderItem.query(on: self.db)
            .filter(\.$item.$id == itemID)
            .filter(\.$order.$id == orderID)
            .first()
    }
}

struct OrderItemRepositoryFactory {
    var make: ((Request) -> OrderItemRepository)?
    
    mutating func use(_ make: @escaping ((Request) -> OrderItemRepository)) {
        self.make = make
    }
}

extension Application {
    private struct OrderItemRepositoryKey: StorageKey {
        typealias Value = OrderItemRepositoryFactory
    }
    
    var orderItems: OrderItemRepositoryFactory {
        get {
            self.storage[OrderItemRepositoryKey.self] ?? .init()
        }
        set {
            self.storage[OrderItemRepositoryKey.self] = newValue
        }
    }
}

extension Request {
    var orderItems: OrderItemRepository {
        self.application.orderItems.make!(self)
    }
}
