//
//  File.swift
//  
//
//  Created by Phan Tran on 10/07/2020.
//

import Foundation
import Fluent

struct AddVolumeDiscountsToOrderItems: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(OrderItem.schema)
            .field("volumeDiscounts", .array(of: .json))
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(OrderItem.schema)
            .deleteField("volumeDiscounts")
            .update()
    }
}
