//
//  File.swift
//  
//
//  Created by Phan Tran on 30/08/2020.
//

import Foundation
import Vapor
import Fluent

struct AddCustomNameToSellerItemSubscription: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(SellerItemSubscription.schema)
            .field("custom_name", .string)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(SellerItemSubscription.schema)
            .deleteField("custom_name")
            .update()
    }
}
