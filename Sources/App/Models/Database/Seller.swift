//
//  File.swift
//  
//
//  Created by Phan Tran on 24/05/2020.
//

import Foundation
import Fluent
import Vapor

final class Seller: Model, Content {
    static var schema: String = "sellers"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Field(key: "password_hash")
    var passwordHash: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?

    @Siblings(through: SellerWarehouseAddress.self, from: \.$seller, to: \.$warehouse)
    var warehouseAddresses: [WarehouseAddress]

    @Children(for: \.$seller)
    var sellerWarehouseAddresses: [SellerWarehouseAddress]

    @Siblings(through: SellerItemSubscription.self, from: \.$seller, to: \.$item)
    var subscribedItems: [Item]
 
    init() { }

    init(name: String,
         passwordHash: String) {
        self.name = name
        self.passwordHash = passwordHash
    }
}
