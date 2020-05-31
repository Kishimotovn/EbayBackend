//
//  File.swift
//  
//
//  Created by Phan Tran on 23/05/2020.
//

import Foundation
import Fluent

struct CreateItems: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(Item.schema)
            .id()
            .field("item_id", .string, .required)
            .field("image_url", .string)
            .field("name", .string)
            .field("condition", .string)
            .field("shipping_price", .int, .required)
            .field("original_price", .int, .required)
            .field("seller_name", .string)
            .field("seller_feedback_count", .int)
            .field("seller_score", .double)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(Item.schema).delete()
    }
}
