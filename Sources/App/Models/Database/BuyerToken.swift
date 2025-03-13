//
//  File.swift
//  
//
//  Created by Phan Tran on 19/05/2020.
//

import Foundation
import Vapor
import Fluent

final class BuyerToken: Model, @unchecked Sendable, Content {
    static let schema = "buyer_tokens"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "value")
    var value: String

    @Field(key: "expired_at")
    var expiredAt: Date

    @Parent(key: "buyer_id")
    var buyer: Buyer

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() { }

    init(id: UUID? = nil,
         value: String,
         expiredAt: Date = Date().addingTimeInterval(60*60*24*60),
         buyerID: Buyer.IDValue) {
        self.id = id
        self.value = value
        self.$buyer.id = buyerID
        self.expiredAt = expiredAt
    }
}
