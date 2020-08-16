//
//  File.swift
//  
//
//  Created by Phan Tran on 16/08/2020.
//

import Foundation
import Vapor
import Fluent

struct AddScanIntervalToSellerItemSubscription: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(SellerItemSubscription.schema)
            .field("scan_interval", .int)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(SellerItemSubscription.schema)
            .deleteField("scan_interval")
            .update()
    }
}
