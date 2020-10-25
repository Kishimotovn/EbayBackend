//
//  File.swift
//  
//
//  Created by Phan Tran on 25/10/2020.
//

import Foundation
import Vapor
import Fluent

struct CreateSellerSellerSubscriptions: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(SellerSellerSubscription.schema)
            .id()
            .field("ebay_seller_name", .string, .required)
            .field("ebay_keyword", .string, .required)
            .field("seller_id", .uuid, .required, .references(Seller.schema, "id"))
            .field("custom_name", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .field("deleted_at", .datetime)
            .field("current_response", .json, .required)
            .field("scan_interval", .int)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(SellerSellerSubscription.schema)
            .delete()
    }
}
