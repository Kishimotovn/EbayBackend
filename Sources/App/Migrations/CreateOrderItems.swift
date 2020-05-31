//
//  File.swift
//  
//
//  Created by Phan Tran on 23/05/2020.
//

import Foundation
import Fluent

struct CreateOrderItems: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(OrderItem.schema)
            .id()
            .field("order_id", .uuid, .required, .references(Order.schema, "id"))
            .field("item_id", .uuid, .required, .references(Item.schema, "id"))
            .field("index", .int8, .required)
            .field("quantity", .int8, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(OrderItem.schema).delete()
    }
}
