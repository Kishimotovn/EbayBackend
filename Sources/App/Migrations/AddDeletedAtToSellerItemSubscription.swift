//
//  File.swift
//  
//
//  Created by Phan Tran on 17/08/2020.
//

import Foundation
import Vapor
import Fluent

struct AddDeletedAtToSellerItemSubscription: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(SellerItemSubscription.schema)
            .field("deleted_at", .datetime)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(SellerItemSubscription.schema)
            .deleteField("deleted_at")
            .update()
    }
}
