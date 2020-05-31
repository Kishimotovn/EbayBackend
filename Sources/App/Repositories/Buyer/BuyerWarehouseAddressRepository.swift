//
//  File.swift
//  
//
//  Created by Phan Tran on 27/05/2020.
//

import Foundation
import Vapor
import Fluent

protocol BuyerWarehouseAddressRepository {
    func find(id: BuyerWarehouseAddress.IDValue) -> EventLoopFuture<BuyerWarehouseAddress?>
    func save(buyerWarehouseAddress: BuyerWarehouseAddress) -> EventLoopFuture<Void>
}

struct DatabaseBuyerWarehouseAddressRepository: BuyerWarehouseAddressRepository {
    let db: Database

    func find(id: BuyerWarehouseAddress.IDValue) -> EventLoopFuture<BuyerWarehouseAddress?> {
        return BuyerWarehouseAddress.query(on: self.db)
            .filter(\.$id == id)
            .with(\.$warehouse)
            .first()
    }

    func save(buyerWarehouseAddress: BuyerWarehouseAddress) -> EventLoopFuture<Void> {
        return buyerWarehouseAddress.save(on: self.db)
    }
}

struct BuyerWarehouseAddressRepositoryFactory {
    var make: ((Request) -> BuyerWarehouseAddressRepository)?
    
    mutating func use(_ make: @escaping ((Request) -> BuyerWarehouseAddressRepository)) {
        self.make = make
    }
}

extension Application {
    private struct BuyerWarehouseAddressRepositoryKey: StorageKey {
        typealias Value = BuyerWarehouseAddressRepositoryFactory
    }
    
    var buyerWarehouseAddresses: BuyerWarehouseAddressRepositoryFactory {
        get {
            self.storage[BuyerWarehouseAddressRepositoryKey.self] ?? .init()
        }
        set {
            self.storage[BuyerWarehouseAddressRepositoryKey.self] = newValue
        }
    }
}

extension Request {
    var buyerWarehouseAddresses: BuyerWarehouseAddressRepository {
        self.application.buyerWarehouseAddresses.make!(self)
    }
}
