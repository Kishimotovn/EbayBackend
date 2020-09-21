//
//  File.swift
//  
//
//  Created by Phan Tran on 18/09/2020.
//

import Foundation
import Vapor
import Fluent

struct CreateSellerItemFeatured: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(SellerItemFeatured.schema)
            .id()
            .field("seller_id", .uuid, .references(Seller.schema, "id"))
            .field("item_id", .uuid, .references(Item.schema, "id"))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .field("deleted_at", .datetime)
            .field("item_end_date", .datetime)
            .field("further_discount_amount", .int)
            .field("volumeDiscounts", .array(of: .json))
            .field("further_discount_detected", .bool, .required, .sql(.default(false)))
            .unique(on: "seller_id", "item_id")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(SellerItemFeatured.schema).delete()
    }
}

