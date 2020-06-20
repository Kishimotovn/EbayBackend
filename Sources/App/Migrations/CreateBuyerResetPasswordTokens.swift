//
//  File.swift
//  
//
//  Created by Phan Tran on 17/06/2020.
//

import Foundation
import Fluent

struct CreateBuyerResetPasswordTokens: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(BuyerResetPasswordToken.schema)
            .id()
            .field("buyer_id", .uuid, .required, .references(Buyer.schema, "id"))
            .field("value", .string, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(BuyerResetPasswordToken.schema)
            .delete()
    }
}
