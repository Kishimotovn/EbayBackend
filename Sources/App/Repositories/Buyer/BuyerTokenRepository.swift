//
//  File.swift
//  
//
//  Created by Phan Tran on 19/05/2020.
//

import Foundation
import Vapor
import Fluent

protocol BuyerTokenRepository {
    func find(value: String) -> EventLoopFuture<BuyerToken?>
    func delete(id: BuyerToken.IDValue) -> EventLoopFuture<Void>
    func save(token: BuyerToken) -> EventLoopFuture<Void>
}

struct DatabaseBuyerTokenRepository: BuyerTokenRepository {
    let db: Database

    func find(value: String) -> EventLoopFuture<BuyerToken?> {
        return BuyerToken
            .query(on: self.db)
            .filter(\.$value == value)
            .first()
    }

    func delete(id: BuyerToken.IDValue) -> EventLoopFuture<Void> {
        return BuyerToken
            .query(on: self.db)
            .filter(\.$id == id)
            .delete()
    }

    func save(token: BuyerToken) -> EventLoopFuture<Void> {
        return token.save(on: self.db)
    }
}

struct BuyerTokenRepositoryFactory: @unchecked Sendable {
    var make: ((Request) -> BuyerTokenRepository)?
    
    mutating func use(_ make: @escaping ((Request) -> BuyerTokenRepository)) {
        self.make = make
    }
}

extension Application {
    private struct BuyerTokenRepositoryKey: StorageKey {
        typealias Value = BuyerTokenRepositoryFactory
    }

    var buyerTokens: BuyerTokenRepositoryFactory {
        get {
            self.storage[BuyerTokenRepositoryKey.self] ?? .init()
        }
        set {
            self.storage[BuyerTokenRepositoryKey.self] = newValue
        }
    }
}

extension Request {
    var buyerTokens: BuyerTokenRepository {
        self.application.buyerTokens.make!(self)
    }
}
