//
//  File.swift
//  
//
//  Created by Phan Tran on 24/05/2020.
//

import Foundation
import Fluent

struct CreateSellers: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(Seller.schema)
            .id()
            .field("name", .string, .required)
            .field("password_hash", .string, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .field("deleted_at", .datetime)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(Seller.schema).delete()
    }
}
