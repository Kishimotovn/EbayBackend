//
//  File.swift
//  
//
//  Created by Phan Tran on 13/06/2020.
//

import Foundation
import Fluent

struct CreateSellerItemSubscriptions: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(SellerItemSubscription.schema)
            .id()
            .field("seller_id", .uuid, .references(Seller.schema, "id"))
            .field("item_id", .uuid, .references(Item.schema, "id"))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(SellerItemSubscription.schema).delete()
    }
}
