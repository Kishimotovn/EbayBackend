//
//  File.swift
//  
//
//  Created by Phan Tran on 25/10/2020.
//

import Foundation
import Vapor
import Fluent

struct AddCreatedAtToAppMetaData: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(AppMetadata.schema)
            .field("created_at", .datetime)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(AppMetadata.schema)
            .deleteField("created_at")
            .update()
    }
}
