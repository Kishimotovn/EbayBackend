//
//  File.swift
//  
//
//  Created by Phan Tran on 26/05/2020.
//

import Foundation
import Vapor
import Fluent

protocol SellerRepository {
    func find(id: Seller.IDValue) -> EventLoopFuture<Seller?>
    func save(seller: Seller) -> EventLoopFuture<Void>
}

struct DatabaseSellerRepository: SellerRepository {
    let db: Database

    func find(id: Seller.IDValue) -> EventLoopFuture<Seller?> {
        return Seller.find(id, on: self.db)
    }

    func save(seller: Seller) -> EventLoopFuture<Void> {
        return seller.save(on: self.db)
    }
}

struct SellerRepositoryFactory: @unchecked Sendable {
    var make: ((Request) -> SellerRepository)?
    
    mutating func use(_ make: @escaping ((Request) -> SellerRepository)) {
        self.make = make
    }
}

extension Application {
    private struct SellerRepositoryKey: StorageKey {
        typealias Value = SellerRepositoryFactory
    }
    
    var sellers: SellerRepositoryFactory {
        get {
            self.storage[SellerRepositoryKey.self] ?? .init()
        }
        set {
            self.storage[SellerRepositoryKey.self] = newValue
        }
    }
}

extension Request {
    var sellers: SellerRepository {
        self.application.sellers.make!(self)
    }
}
