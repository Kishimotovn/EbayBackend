//
//  File.swift
//  
//
//  Created by Phan Tran on 20/06/2020.
//

import Foundation
import Fluent

struct AddFurtherDiscountDetectedToOrderItem: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(OrderItem.schema)
            .field("further_discount_detected", .bool, .required, .sql(.default(false)))
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(OrderItem.schema)
            .deleteField("further_discount_detected")
            .update()
    }
}
