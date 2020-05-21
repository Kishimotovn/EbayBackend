//
//  File.swift
//  
//
//  Created by Phan Tran on 19/05/2020.
//

import Foundation
import Vapor
import Fluent

protocol BuyerRepository {
    func find(buyerID: Buyer.IDValue) -> EventLoopFuture<Buyer?>
    func save(buyer: Buyer) -> EventLoopFuture<Void>
}

struct DatabaseBuyerRepository: BuyerRepository {
    let db: Database

    func save(buyer: Buyer) -> EventLoopFuture<Void> {
        return buyer.save(on: self.db)
    }

    func find(buyerID: Buyer.IDValue) -> EventLoopFuture<Buyer?> {
        return Buyer.find(buyerID, on: self.db)
    }
}

struct BuyerRepositoryFactory {
    var make: ((Request) -> BuyerRepository)?

    mutating func use(_ make: @escaping ((Request) -> BuyerRepository)) {
        self.make = make
    }
}

extension Application {
    private struct BuyerRepositoryKey: StorageKey {
        typealias Value = BuyerRepositoryFactory
    }

    var buyers: BuyerRepositoryFactory {
        get {
            self.storage[BuyerRepositoryKey.self] ?? .init()
        }
        set {
            self.storage[BuyerRepositoryKey.self] = newValue
        }
    }
}

extension Request {
    var buyers: BuyerRepository {
        self.application.buyers.make!(self)
    }
}
