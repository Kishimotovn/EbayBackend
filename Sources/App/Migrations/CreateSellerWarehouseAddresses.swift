//
//  File.swift
//  
//
//  Created by Phan Tran on 25/05/2020.
//

import Foundation
import Fluent

struct CreateSellerWarehouseAddresses: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(SellerWarehouseAddress.schema)
            .id()
            .field("name", .string, .required)
            .field("seller_id", .uuid, .required, .references(Seller.schema, "id"))
            .field("warehouse_id", .uuid, .required, .references(WarehouseAddress.schema, "id"))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(SellerWarehouseAddress.schema).delete()
    }
}
