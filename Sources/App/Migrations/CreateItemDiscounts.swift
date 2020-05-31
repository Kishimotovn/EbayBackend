//
//  File.swift
//  
//
//  Created by Phan Tran on 23/05/2020.
//

import Foundation
import Fluent

struct CreateItemDiscounts: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(ItemDiscount.schema)
            .id()
            .field("amount", .int, .required)
            .field("discount_type", .string, .required)
            .field("item_id", .uuid, .required, .references(Item.schema, "id"))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(ItemDiscount.schema).delete()
    }
}
