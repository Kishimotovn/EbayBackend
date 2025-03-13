//
//  File.swift
//  
//
//  Created by Phan Tran on 25/10/2020.
//

import Foundation
import Vapor
import Fluent

protocol SellerSellerSubscriptionRepository {
    func find(subscriptionID: SellerSellerSubscription.IDValue) -> EventLoopFuture<SellerSellerSubscription?>
    func find(sellerID: Seller.IDValue) -> EventLoopFuture<[SellerSellerSubscription]>
    func save(subscription: SellerSellerSubscription) -> EventLoopFuture<Void>
    func delete(subscriptionID: SellerSellerSubscription.IDValue) -> EventLoopFuture<Void>
}

struct DatabaseSellerSellerSubscriptionRepository: SellerSellerSubscriptionRepository {
    let db: Database

    func find(subscriptionID: SellerSellerSubscription.IDValue) -> EventLoopFuture<SellerSellerSubscription?> {
        return SellerSellerSubscription.find(subscriptionID, on: self.db)
    }

    func find(sellerID: Seller.IDValue) -> EventLoopFuture<[SellerSellerSubscription]> {
        return SellerSellerSubscription.query(on: self.db)
            .filter(\.$seller.$id == sellerID)
            .all()
    }

    func save(subscription: SellerSellerSubscription) -> EventLoopFuture<Void> {
        return subscription.save(on: self.db)
    }

    func delete(subscriptionID: SellerSellerSubscription.IDValue) -> EventLoopFuture<Void> {
        return SellerSellerSubscription.query(on: self.db)
            .filter(\.$id == subscriptionID)
            .delete()
    }
}

struct SellerSellerSubscriptionRepositoryFactory: @unchecked Sendable {
    var make: ((Request) -> SellerSellerSubscriptionRepository)?
    
    mutating func use(_ make: @escaping ((Request) -> SellerSellerSubscriptionRepository)) {
        self.make = make
    }
}

extension Application {
    private struct SellerSellerSubscriptionRepositoryKey: StorageKey {
        typealias Value = SellerSellerSubscriptionRepositoryFactory
    }

    var sellerSubscriptions: SellerSellerSubscriptionRepositoryFactory {
        get {
            self.storage[SellerSellerSubscriptionRepositoryKey.self] ?? .init()
        }
        set {
            self.storage[SellerSellerSubscriptionRepositoryKey.self] = newValue
        }
    }
}

extension Request {
    var sellerSubscriptions: SellerSellerSubscriptionRepository {
        self.application.sellerSubscriptions.make!(self)
    }
}
