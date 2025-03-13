//
//  File.swift
//  
//
//  Created by Phan Tran on 04/08/2020.
//

import Foundation
import Vapor
import Fluent

protocol SellerTokenRepository {
    func find(value: String) -> EventLoopFuture<SellerToken?>
    func delete(id: SellerToken.IDValue) -> EventLoopFuture<Void>
    func save(token: SellerToken) -> EventLoopFuture<Void>
}

struct DatabaseSellerTokenRepository: SellerTokenRepository {
    let db: Database

    func find(value: String) -> EventLoopFuture<SellerToken?> {
        return SellerToken
            .query(on: self.db)
            .filter(\.$value == value)
            .first()
    }
    
    func delete(id: SellerToken.IDValue) -> EventLoopFuture<Void> {
        return SellerToken
            .query(on: self.db)
            .filter(\.$id == id)
            .delete()
    }
    
    func save(token: SellerToken) -> EventLoopFuture<Void> {
        return token.save(on: self.db)
    }
}

struct SellerTokenRepositoryFactory: @unchecked Sendable {
    var make: ((Request) -> SellerTokenRepository)?
    
    mutating func use(_ make: @escaping ((Request) -> SellerTokenRepository)) {
        self.make = make
    }
}

extension Application {
    private struct SellerTokenRepositoryKey: StorageKey {
        typealias Value = SellerTokenRepositoryFactory
    }
    
    var sellerTokens: SellerTokenRepositoryFactory {
        get {
            self.storage[SellerTokenRepositoryKey.self] ?? .init()
        }
        set {
            self.storage[SellerTokenRepositoryKey.self] = newValue
        }
    }
}

extension Request {
    var sellerTokens: SellerTokenRepository {
        self.application.sellerTokens.make!(self)
    }
}
