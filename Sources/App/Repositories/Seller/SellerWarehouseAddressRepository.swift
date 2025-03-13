//
//  File.swift
//  
//
//  Created by Phan Tran on 28/05/2020.
//

import Foundation
import Vapor
import Fluent

protocol SellerWarehouseAddressRepository {
    func find(id: SellerWarehouseAddress.IDValue) -> EventLoopFuture<SellerWarehouseAddress?>
}

struct DatabaseSellerWarehouseAddressRepository: SellerWarehouseAddressRepository {
    let db: Database

    func find(id: SellerWarehouseAddress.IDValue) -> EventLoopFuture<SellerWarehouseAddress?> {
        return SellerWarehouseAddress.query(on: self.db)
            .filter(\.$id == id)
            .with(\.$warehouse)
            .first()
    }
}

struct SellerWarehouseAddressRepositoryFactory: @unchecked Sendable {
    var make: ((Request) -> SellerWarehouseAddressRepository)?
    
    mutating func use(_ make: @escaping ((Request) -> SellerWarehouseAddressRepository)) {
        self.make = make
    }
}

extension Application {
    private struct SellerWarehouseAddressRepositoryKey: StorageKey {
        typealias Value = SellerWarehouseAddressRepositoryFactory
    }

    var sellerWarehouseAddresses: SellerWarehouseAddressRepositoryFactory {
        get {
            self.storage[SellerWarehouseAddressRepositoryKey.self] ?? .init()
        }
        set {
            self.storage[SellerWarehouseAddressRepositoryKey.self] = newValue
        }
    }
}

extension Request {
    var sellerWarehouseAddresses: SellerWarehouseAddressRepository {
        self.application.sellerWarehouseAddresses.make!(self)
    }
}
