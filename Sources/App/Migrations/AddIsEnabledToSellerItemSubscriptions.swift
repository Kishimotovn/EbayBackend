//
//  File.swift
//  
//
//  Created by Phan Tran on 08/11/2020.
//

import Foundation
import Fluent
import Vapor

struct AddIsEnabledToSellerItemSubscription: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(SellerItemSubscription.schema)
            .field("is_enabled", .bool, .required, .sql(raw: "DEFAULT TRUE"))
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(SellerItemSubscription.schema)
            .deleteField("is_enabled")
            .update()
    }
}
