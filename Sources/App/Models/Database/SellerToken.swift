//
//  File.swift
//  
//
//  Created by Phan Tran on 24/05/2020.
//

import Foundation
import Vapor
import Fluent

final class SellerToken: Model, Content {
    static let schema = "seller_tokens"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "value")
    var value: String

    @Field(key: "expired_at")
    var expiredAt: Date

    @Parent(key: "seller_id")
    var seller: Seller

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() { }

    init(id: UUID? = nil,
         value: String,
         expiredAt: Date = Date().addingTimeInterval(60*60*24*60),
         sellerID: Seller.IDValue) {
        self.id = id
        self.value = value
        self.$seller.id = sellerID
        self.expiredAt = expiredAt
    }
}
