//
//  File.swift
//  
//
//  Created by Phan Tran on 08/11/2020.
//

import Foundation
import Fluent
import Vapor

struct AddIsEnabledToSellerSellerSubscription: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(SellerSellerSubscription.schema)
            .field("is_enabled", .bool, .required, .sql(raw: "DEFAULT TRUE"))
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(SellerSellerSubscription.schema)
            .deleteField("is_enabled")
            .update()
    }
}
