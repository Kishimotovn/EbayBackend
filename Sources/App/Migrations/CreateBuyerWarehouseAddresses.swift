//
//  File.swift
//  
//
//  Created by Phan Tran on 24/05/2020.
//

import Foundation
import Fluent

struct CreateBuyerWarehouseAddresses: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(BuyerWarehouseAddress.schema)
            .id()
            .field("name", .string, .required)
            .field("buyer_id", .uuid, .required, .references(Buyer.schema, "id"))
            .field("warehouse_id", .uuid, .required, .references(WarehouseAddress.schema, "id"))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(BuyerWarehouseAddress.schema).delete()
    }
}
