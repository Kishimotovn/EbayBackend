//
//  File.swift
//  
//
//  Created by Phan Tran on 23/05/2020.
//

import Foundation
import Vapor
import Fluent

struct CreateWarehouseAddresses: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(WarehouseAddress.schema)
            .id()
            .field("address_line_1", .string, .required)
            .field("address_line_2", .string)
            .field("city", .string, .required)
            .field("state", .string, .required)
            .field("zip_code", .string, .required)
            .field("phone_number", .string, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(WarehouseAddress.schema).delete()
    }
}
