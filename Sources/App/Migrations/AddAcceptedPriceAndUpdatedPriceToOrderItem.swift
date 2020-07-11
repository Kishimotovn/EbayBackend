//
//  File.swift
//  
//
//  Created by Phan Tran on 11/07/2020.
//

import Foundation
import Fluent

struct AddAcceptedPriceAndUpdatedPriceToOrderItem: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(OrderItem.schema)
            .field("updated_price", .int)
            .field("accepted_price", .int, .required, .sql(.default(0)))
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(OrderItem.schema)
            .deleteField("updated_price")
            .deleteField("accepted_price")
            .update()
    }
}
