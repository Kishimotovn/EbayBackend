//
//  File.swift
//  
//
//  Created by Phan Tran on 29/09/2020.
//

import Foundation
import Fluent

struct AddPriceToSellerItemFeatured: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(SellerItemFeatured.schema)
            .field("price", .int)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(SellerItemFeatured.schema)
            .deleteField("price")
            .update()
    }
}
