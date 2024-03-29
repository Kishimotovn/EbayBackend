//
//  File.swift
//  
//
//  Created by Phan Tran on 19/05/2020.
//

import Foundation
import Fluent

struct CreateBuyerTokens: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(BuyerToken.schema)
            .id()
            .field("value", .string, .required)
            .field("created_at", .datetime)
            .field("expired_at", .datetime, .required)
            .field("buyer_id", .uuid, .required, .references(Buyer.schema, "id"))
            .unique(on: "value")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(BuyerToken.schema).delete()
    }
}

