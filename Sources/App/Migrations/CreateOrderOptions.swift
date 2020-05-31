//
//  File.swift
//  
//
//  Created by Phan Tran on 24/05/2020.
//

import Foundation
import Fluent

struct CreateOrderOptions: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(OrderOption.schema)
            .id()
            .field("name", .string, .required)
            .field("rate", .int8, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .field("deleted_at", .datetime)
            .unique(on: "name")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(OrderOption.schema).delete()
    }
}
