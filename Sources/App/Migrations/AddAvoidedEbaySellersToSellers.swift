//
//  File.swift
//  
//
//  Created by Phan Tran on 04/08/2020.
//

import Foundation
import Fluent

struct AddAvoidedEbaySellersToSeller: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(Seller.schema)
            .field("avoided_ebay_sellers", .array(of: .string))
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(Seller.schema)
            .deleteField("avoided_ebay_sellers")
            .update()
    }
}
