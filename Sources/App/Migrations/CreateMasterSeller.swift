//
//  File.swift
//  
//
//  Created by Phan Tran on 25/05/2020.
//

import Foundation
import Fluent
import Vapor

struct CreateMasterSeller: Migration {
    static let masterName = "minhdung910@gmail.com"
    static let masterWarehouseName = "AnnaVu 79"
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        let name = CreateMasterSeller.masterName
        let passwordHash = try! Bcrypt.hash("68686868")

        let masterSeller = Seller(name: name, passwordHash: passwordHash)

        let masterWarehouse = WarehouseAddress(
            addressLine1: "9236 SE Woodstock Blvd, JmD",
            city: "Portland",
            state: "Oregon",
            zipCode: "97266-5274",
            phoneNumber: "219-932-3095")

        return masterSeller.save(on: database)
            .and(masterWarehouse.save(on: database))
            .flatMap { _ in
                do {
                    let masterSellerID = try masterSeller.requireID()
                    let masterWarehouseID = try masterWarehouse.requireID()
                    let pivot = SellerWarehouseAddress(
                        name: CreateMasterSeller.masterWarehouseName,
                        sellerID: masterSellerID,
                        warehouseID: masterWarehouseID)
                    return pivot.save(on: database)
                } catch let error {
                    return database.eventLoop.makeFailedFuture(error)
                }
        }
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return SellerWarehouseAddress.query(on: database)
            .with(\.$seller)
            .with(\.$warehouse)
            .filter(\.$name == CreateMasterSeller.masterWarehouseName)
            .first()
            .optionalFlatMap { warehousePivot in
                return .andAllSucceed([
                    warehousePivot.delete(on: database),
                    warehousePivot.seller.delete(on: database),
                    warehousePivot.warehouse.delete(on: database)
                ], on: database.eventLoop)
            }.transform(to: ())
    }
}
