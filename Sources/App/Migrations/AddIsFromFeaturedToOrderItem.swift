//
//  File.swift
//  
//
//  Created by Phan Tran on 29/09/2020.
//

import Foundation
import Vapor
import Fluent

struct AddIsFromFeaturedToOrderItem: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(OrderItem.schema)
            .field("is_from_featured", .bool, .required, .sql(.default(false)))
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(OrderItem.schema)
            .deleteField("is_from_featured")
            .update()
    }
}
