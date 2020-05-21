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
        return database.schema("buyer_tokens")
            .id()
            .field("value", .string, .required)
            .field("expired_at", .datetime, .required)
            .field("buyer_id", .uuid, .required, .references("buyers", "id"))
            .unique(on: "value")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("buyer_tokens").delete()
    }
}

