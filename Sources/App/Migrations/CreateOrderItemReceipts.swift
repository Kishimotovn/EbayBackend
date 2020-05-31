//
//  File.swift
//  
//
//  Created by Phan Tran on 23/05/2020.
//

import Foundation
import Vapor
import Fluent

struct CreateOrderItemReceipts: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(OrderItemReceipt.schema)
            .id()
            .field("order_item_id", .uuid, .required, .references(OrderItem.schema, "id"))
            .field("image_url", .string, .required)
            .field("tracking_number", .string)
            .field("resolved_quantity", .int8, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(OrderItemReceipt.schema).delete()
    }
}
