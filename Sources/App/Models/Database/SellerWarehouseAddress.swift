//
//  File.swift
//  
//
//  Created by Phan Tran on 25/05/2020.
//

import Foundation
import Fluent

final class SellerWarehouseAddress: Model, @unchecked Sendable {
    static let schema: String = "seller_warehouse_addresses"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Parent(key: "seller_id")
    var seller: Seller

    @Parent(key: "warehouse_id")
    var warehouse: WarehouseAddress

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() { }

    init(name: String, sellerID: Seller.IDValue, warehouseID: WarehouseAddress.IDValue) {
        self.name = name
        self.$seller.id = sellerID
        self.$warehouse.id = warehouseID
    }
}
