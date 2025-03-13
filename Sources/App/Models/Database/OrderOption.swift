//
//  File.swift
//  
//
//  Created by Phan Tran on 24/05/2020.
//

import Foundation
import Vapor
import Fluent

final class OrderOption: Model, @unchecked Sendable, Content {
    static let schema: String = "order_options"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Field(key: "rate")
    var rate: Int

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?

    init() { }

    init(name: String, rate: Int) {
        self.name = name
        self.rate = rate
    }
}

extension OrderOption: Parameter { }
