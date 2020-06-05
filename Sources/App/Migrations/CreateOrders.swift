//
//  File.swift
//  
//
//  Created by Phan Tran on 23/05/2020.
//

import Foundation
import Fluent

struct CreateOrders: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(Order.schema)
            .id()
            .field("order_index", .uint32, .required)
            .field("buyer_id", .uuid, .required, .references(Buyer.schema, "id"))
            .field("seller_id", .uuid, .references(Seller.schema, "id"))
            .field("warehouse_address_id", .uuid, .references(WarehouseAddress.schema, "id"))
            .field("state", .string, .required)
            .field("order_registered_at", .datetime)
            .field("order_option_id", .uuid, .references(OrderOption.schema, "id"))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .field("deleted_at", .datetime)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("orders").delete()
    }
}
