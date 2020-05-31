//
//  File.swift
//  
//
//  Created by Phan Tran on 23/05/2020.
//

import Foundation
import Fluent

final class BuyerWarehouseAddress: Model {
    static let schema: String = "buyer_warehouse_addresses"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Parent(key: "buyer_id")
    var buyer: Buyer

    @Parent(key: "warehouse_id")
    var warehouse: WarehouseAddress

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() { }

    init(name: String, buyerID: Buyer.IDValue, warehouseID: WarehouseAddress.IDValue) {
        self.name = name
        self.$buyer.id = buyerID
        self.$warehouse.id = warehouseID
    }
}
