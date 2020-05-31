//
//  File.swift
//  
//
//  Created by Phan Tran on 25/05/2020.
//

import Foundation
import Fluent

struct CreateSellerTokens: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(SellerToken.schema)
            .id()
            .field("value", .string, .required)
            .field("created_at", .datetime)
            .field("expired_at", .datetime, .required)
            .field("seller_id", .uuid, .required, .references(Seller.schema, "id"))
            .unique(on: "value")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(SellerToken.schema).delete()
    }
}

