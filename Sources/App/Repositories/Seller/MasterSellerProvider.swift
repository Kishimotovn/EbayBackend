//
//  File.swift
//  
//
//  Created by Phan Tran on 26/05/2020.
//

import Foundation
import Vapor
import Fluent

struct MasterSellerID: StorageKey {
    typealias Value = Seller.IDValue
}

extension Application {
    var masterSellerID: Seller.IDValue? {
        get { self.storage[MasterSellerID.self] }
        set { self.storage[MasterSellerID.self] = newValue }
    }
}

struct MasterSellerRegistration: LifecycleHandler {
    func didBoot(_ application: Application) throws {
        _ = Seller.query(on: application.db)
            .filter(\.$name == CreateMasterSeller.masterName)
            .first()
            .flatMapThrowing { seller in
                if let masterSeller = seller {
                    application.masterSellerID = try masterSeller.requireID()
                }
        }
    }
}
