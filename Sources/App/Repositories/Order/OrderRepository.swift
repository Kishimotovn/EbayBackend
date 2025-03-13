//
//  File.swift
//  
//
//  Created by Phan Tran on 25/05/2020.
//

import Foundation
import Vapor
import Fluent

protocol OrderRepository {
    func find(orderID: Order.IDValue) -> EventLoopFuture<Order?>
    func save(order: Order) -> EventLoopFuture<Void>
    func getCartOrder(of buyerID: Buyer.IDValue) -> EventLoopFuture<Order?>
    func getActiveOrders(buyerID: Buyer.IDValue, pageRequest: PageRequest) -> EventLoopFuture<Page<Order>>
    func getInactiveOrders(buyerID: Buyer.IDValue, pageRequest: PageRequest) -> EventLoopFuture<Page<Order>>
    func getActiveOrders(sellerID: Seller.IDValue, pageRequest: PageRequest) -> EventLoopFuture<Page<Order>>
    func getCurrentActiveOrder(sellerID: Seller.IDValue) -> EventLoopFuture<Order?>
    func getWaitingForTrackingOrders(sellerID: Seller.IDValue, pageRequest: PageRequest) -> EventLoopFuture<Page<Order>>
    func getOrder(orderID: Order.IDValue, for sellerID: Seller.IDValue) -> EventLoopFuture<Order?>
    func getWaitingForBuyerVerificationOrders(buyerID: Buyer.IDValue) -> EventLoopFuture<[Order]>
}

struct DatabaseOrderRepository: OrderRepository {
    let db: Database

    func find(orderID: Order.IDValue) -> EventLoopFuture<Order?> {
        return Order.find(orderID, on: self.db)
    }

    func getWaitingForBuyerVerificationOrders(buyerID: Buyer.IDValue) -> EventLoopFuture<[Order]> {
        return Order.query(on: self.db)
            .filter(\.$buyer.$id == buyerID)
            .filter(\.$state == Order.State.buyerVerificationRequired)
            .all()
    }

    func getCartOrder(of buyerID: Buyer.IDValue) -> EventLoopFuture<Order?> {
        return Order.query(on: self.db)
            .filter(\Order.$buyer.$id == buyerID)
            .filter(\Order.$state == Order.State.cart)
            .with(\.$orderItems) {
                $0.with(\.$item)
            }
            .first()
    }

    func save(order: Order) -> EventLoopFuture<Void> {
        if order.id != nil {
            return order.save(on: self.db)
        } else {
            return Order.query(on: self.db)
                .count()
                .flatMap { count in
                    order.orderIndex = count + 1
                    return order.save(on: self.db)
            }
        }
    }

    func getActiveOrders(sellerID: Seller.IDValue,
                         pageRequest: PageRequest) -> EventLoopFuture<Page<Order>> {
        return Order.query(on: self.db)
            .filter(\.$seller.$id == sellerID)
            .filter(\.$state ~~ [.registered, .inProgress])
            .with(\.$orderItems) {
                $0.with(\.$item)
                $0.with(\.$receipts)
            }
            .with(\.$orderOption)
            .with(\.$warehouseAddress)
            .join(OrderOption.self, on: \Order.$orderOption.$id == \OrderOption.$id)
            .sort(OrderOption.self, \.$rate, .descending)
            .sort(\.$orderRegisteredAt, .ascending)
            .paginate(pageRequest)
    }

    func getWaitingForTrackingOrders(sellerID: Seller.IDValue,
                                     pageRequest: PageRequest) -> EventLoopFuture<Page<Order>> {
        return Order.query(on: self.db)
            .filter(\.$seller.$id == sellerID)
            .filter(\.$state == .waitingForTracking)
            .join(OrderOption.self, on: \Order.$orderOption.$id == \OrderOption.$id)
            .sort(OrderOption.self, \.$rate, .descending)
            .sort(\.$orderRegisteredAt, .ascending)
            .with(\.$orderItems) {
                $0.with(\.$item)
                $0.with(\.$receipts)
            }
            .with(\.$orderOption)
            .with(\.$warehouseAddress)
            .paginate(pageRequest)
    }

    func getActiveOrders(buyerID: Buyer.IDValue,
                         pageRequest: PageRequest) -> EventLoopFuture<Page<Order>> {
        return Order.query(on: self.db)
            .filter(\.$buyer.$id == buyerID)
            .filter(\.$state ~~ [.buyerVerificationRequired, .priceChanged, .registered, .inProgress, .waitingForTracking])
            .sort(\.$orderRegisteredAt, .descending)
            .with(\.$orderItems) {
                $0.with(\.$item)
                $0.with(\.$receipts)
            }
            .with(\.$orderOption)
            .with(\.$warehouseAddress)
            .paginate(pageRequest)
    }

    func getInactiveOrders(buyerID: Buyer.IDValue, pageRequest: PageRequest) -> EventLoopFuture<Page<Order>> {
        return Order.query(on: self.db)
            .filter(\.$buyer.$id == buyerID)
            .filter(\.$state ~~ [.delivered, .failed, .stuck])
            .sort(\.$updatedAt, .descending)
            .with(\.$orderItems) {
                $0.with(\.$item)
                $0.with(\.$receipts)
            }
            .with(\.$orderOption)
            .with(\.$warehouseAddress)
            .paginate(pageRequest)
    }

    func getCurrentActiveOrder(sellerID: Seller.IDValue) -> EventLoopFuture<Order?> {
        return Order.query(on: self.db)
            .filter(\.$seller.$id == sellerID)
            .filter(\.$state == .inProgress)
            .join(OrderOption.self, on: \Order.$orderOption.$id == \OrderOption.$id)
            .sort(OrderOption.self, \.$rate, .descending)
            .sort(\.$orderRegisteredAt, .ascending)
            .first()
    }

    func getOrder(orderID: Order.IDValue, for sellerID: Seller.IDValue) -> EventLoopFuture<Order?> {
        return Order.query(on: self.db)
            .filter(\.$id == orderID)
            .filter(\.$seller.$id == sellerID)
            .with(\.$orderItems) {
                $0.with(\.$item)
                $0.with(\.$receipts)
            }
            .with(\.$orderOption)
            .with(\.$warehouseAddress)
            .with(\.$buyer)
            .first()
    }
}

struct OrderRepositoryFactory: @unchecked Sendable {
    var make: ((Request) -> OrderRepository)?

    mutating func use(_ make: @escaping ((Request) -> OrderRepository)) {
        self.make = make
    }
}

extension Application {
    private struct OrderRepositoryKey: StorageKey {
        typealias Value = OrderRepositoryFactory
    }

    var orders: OrderRepositoryFactory {
        get {
            self.storage[OrderRepositoryKey.self] ?? .init()
        }
        set {
            self.storage[OrderRepositoryKey.self] = newValue
        }
    }
}

extension Request {
    var orders: OrderRepository {
        self.application.orders.make!(self)
    }
}

