//
//  File.swift
//  
//
//  Created by Phan Tran on 17/06/2020.
//

import Foundation
import Fluent

struct AddVerifiedAtToBuyer: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(Buyer.schema)
            .field("verified_at", .datetime)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(Buyer.schema)
            .deleteField("verified_at")
            .update()
    }
}
