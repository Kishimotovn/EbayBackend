//
//  File.swift
//  
//
//  Created by Phan Tran on 28/05/2020.
//

import Foundation
import Vapor
import Fluent

protocol OrderItemReceiptRepository {
    func save(orderItemReceipt: OrderItemReceipt) -> EventLoopFuture<Void>
    func find(id: OrderItemReceipt.IDValue) -> EventLoopFuture<OrderItemReceipt?>
    func find(orderItemID: OrderItem.IDValue, orderItemReceiptID: OrderItemReceipt.IDValue) -> EventLoopFuture<OrderItemReceipt?>
    func delete(orderItemReceipt: OrderItemReceipt) -> EventLoopFuture<Void>
}

struct DatabaseOrderItemReceiptRepository: OrderItemReceiptRepository {
    let db: Database

    func find(id: OrderItemReceipt.IDValue) -> EventLoopFuture<OrderItemReceipt?> {
        return OrderItemReceipt.find(id, on: self.db)
    }

    func save(orderItemReceipt: OrderItemReceipt) -> EventLoopFuture<Void> {
        return orderItemReceipt.save(on: self.db)
    }

    func find(orderItemID: OrderItem.IDValue, orderItemReceiptID: OrderItemReceipt.IDValue) -> EventLoopFuture<OrderItemReceipt?> {
        return OrderItemReceipt
            .query(on: self.db)
            .filter(\.$id == orderItemReceiptID)
            .filter(\.$orderItem.$id == orderItemID)
            .first()
    }

    func delete(orderItemReceipt: OrderItemReceipt) -> EventLoopFuture<Void> {
        return orderItemReceipt
            .delete(on: self.db)
    }
}

struct OrderItemReceiptRepositoryFactory: @unchecked Sendable {
    var make: ((Request) -> OrderItemReceiptRepository)?
    
    mutating func use(_ make: @escaping ((Request) -> OrderItemReceiptRepository)) {
        self.make = make
    }
}

extension Application {
    private struct OrderItemReceiptRepositoryKey: StorageKey {
        typealias Value = OrderItemReceiptRepositoryFactory
    }
    
    var orderItemReceipts: OrderItemReceiptRepositoryFactory {
        get {
            self.storage[OrderItemReceiptRepositoryKey.self] ?? .init()
        }
        set {
            self.storage[OrderItemReceiptRepositoryKey.self] = newValue
        }
    }
}

extension Request {
    var orderItemReceipts: OrderItemReceiptRepository {
        self.application.orderItemReceipts.make!(self)
    }
}
