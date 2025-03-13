//
//  File.swift
//  
//
//  Created by Phan Tran on 17/06/2020.
//

import Foundation
import Vapor
import Fluent

protocol BuyerResetPasswordTokenRepository {
    func deleteAll(buyerID: Buyer.IDValue) -> EventLoopFuture<Void>
    func find(value: String) -> EventLoopFuture<BuyerResetPasswordToken?>
    func save(buyerResetPasswordToken: BuyerResetPasswordToken) -> EventLoopFuture<Void>
}

struct DatabaseBuyerResetPasswordTokenRepository: BuyerResetPasswordTokenRepository {
    let db: Database

    
    func deleteAll(buyerID: Buyer.IDValue) -> EventLoopFuture<Void> {
        return BuyerResetPasswordToken.query(on: self.db)
            .filter(\.$buyer.$id == buyerID)
            .delete()
    }

    func find(value: String) -> EventLoopFuture<BuyerResetPasswordToken?> {
        return BuyerResetPasswordToken.query(on: self.db)
            .filter(\.$value == value)
            .with(\.$buyer)
            .first()
    }

    func save(buyerResetPasswordToken: BuyerResetPasswordToken) -> EventLoopFuture<Void> {
        return buyerResetPasswordToken.save(on: self.db)
    }
}

struct BuyerResetPasswordTokenRepositoryFactory: @unchecked Sendable {
    var make: ((Request) -> BuyerResetPasswordTokenRepository)?

    mutating func use(_ make: @escaping ((Request) -> BuyerResetPasswordTokenRepository)) {
        self.make = make
    }
}

extension Application {
    private struct BuyerResetPasswordTokenRepositoryKey: StorageKey {
        typealias Value = BuyerResetPasswordTokenRepositoryFactory
    }
    
    var buyerResetPasswordTokens: BuyerResetPasswordTokenRepositoryFactory {
        get {
            self.storage[BuyerResetPasswordTokenRepositoryKey.self] ?? .init()
        }
        set {
            self.storage[BuyerResetPasswordTokenRepositoryKey.self] = newValue
        }
    }
}

extension Request {
    var buyerResetPasswordTokens: BuyerResetPasswordTokenRepository {
        self.application.buyerResetPasswordTokens.make!(self)
    }
}
