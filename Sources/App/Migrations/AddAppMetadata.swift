//
//  File.swift
//  
//
//  Created by Phan Tran on 23/09/2020.
//

import Foundation
import Vapor
import Fluent

struct AddAppMetadata: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(AppMetadata.schema)
            .id()
            .field("scan_count", .int)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(AppMetadata.schema)
            .delete()
    }
}
