//
//  File.swift
//  
//
//  Created by Phan Tran on 27/05/2020.
//

import Foundation
import Vapor
import Fluent

protocol WarehouseAddressRepository {
    func save(warehouseAddress: WarehouseAddress) -> EventLoopFuture<Void>
    func validateAccess(to warehouseID: WarehouseAddress.IDValue,
                        for buyerID: Buyer.IDValue) -> EventLoopFuture<Bool>
}

struct DatabaseWarehouseAddressRepository: WarehouseAddressRepository {
    let db: Database

    func save(warehouseAddress: WarehouseAddress) -> EventLoopFuture<Void> {
        return warehouseAddress.save(on: self.db)
    }

    func validateAccess(to warehouseID: WarehouseAddress.IDValue,
                        for buyerID: Buyer.IDValue) -> EventLoopFuture<Bool> {
        let buyerWarehouseAddressFuture = BuyerWarehouseAddress.query(on: self.db)
            .filter(\.$buyer.$id == buyerID)
            .filter(\.$warehouse.$id == warehouseID)
            .first()
        let sellerWarehouseAddressFuture = SellerWarehouseAddress.query(on: self.db)
            .filter(\.$warehouse.$id == warehouseID)
            .first()

        return buyerWarehouseAddressFuture
            .and(sellerWarehouseAddressFuture)
            .map { buyerWarehouse, sellerWarehouse in
                if buyerWarehouse != nil || sellerWarehouse != nil {
                    return true
                }
                return false
        }
    }
}

struct WarehouseAddressRepositoryFactory: @unchecked Sendable {
    var make: ((Request) -> WarehouseAddressRepository)?
    
    mutating func use(_ make: @escaping ((Request) -> WarehouseAddressRepository)) {
        self.make = make
    }
}

extension Application {
    private struct WarehouseAddressRepositoryKey: StorageKey {
        typealias Value = WarehouseAddressRepositoryFactory
    }
    
    var warehouseAddresses: WarehouseAddressRepositoryFactory {
        get {
            self.storage[WarehouseAddressRepositoryKey.self] ?? .init()
        }
        set {
            self.storage[WarehouseAddressRepositoryKey.self] = newValue
        }
    }
}

extension Request {
    var warehouseAddresses: WarehouseAddressRepository {
        self.application.warehouseAddresses.make!(self)
    }
}
