//
//  File.swift
//  
//
//  Created by Phan Tran on 14/06/2020.
//

import Foundation
import Vapor
import Fluent

protocol SellerItemSubscriptionRepository {
    func find(itemID: Item.IDValue, sellerID: Seller.IDValue) -> EventLoopFuture<SellerItemSubscription?>
    func delete(sellerItemSubscription: SellerItemSubscription) -> EventLoopFuture<Void>
}

struct DatabaseSellerItemSubscriptionRepository: SellerItemSubscriptionRepository {
    let db: Database

    func find(itemID: Item.IDValue, sellerID: Seller.IDValue) -> EventLoopFuture<SellerItemSubscription?> {
        return SellerItemSubscription.query(on: self.db)
            .filter(\.$item.$id == itemID)
            .filter(\.$seller.$id == sellerID)
            .with(\.$item)
            .first()
    }

    func delete(sellerItemSubscription: SellerItemSubscription) -> EventLoopFuture<Void> {
        return sellerItemSubscription.delete(on: self.db)
    }
}

struct SellerItemSubscriptionRepositoryFactory: @unchecked Sendable {
    var make: ((Request) -> SellerItemSubscriptionRepository)?
    
    mutating func use(_ make: @escaping ((Request) -> SellerItemSubscriptionRepository)) {
        self.make = make
    }
}

extension Application {
    private struct SellerItemSubscriptionRepositoryKey: StorageKey {
        typealias Value = SellerItemSubscriptionRepositoryFactory
    }

    var sellerItemSubscriptions: SellerItemSubscriptionRepositoryFactory {
        get {
            self.storage[SellerItemSubscriptionRepositoryKey.self] ?? .init()
        }
        set {
            self.storage[SellerItemSubscriptionRepositoryKey.self] = newValue
        }
    }
}

extension Request {
    var sellerItemSubscriptions: SellerItemSubscriptionRepository {
        self.application.sellerItemSubscriptions.make!(self)
    }
}
