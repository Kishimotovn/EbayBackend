//
//  File.swift
//  
//
//  Created by Phan Tran on 25/10/2020.
//

import Foundation
import Vapor
import Fluent

final class SellerSellerSubscription: Model, Content {
    static var schema: String = "seller_seller_subscription"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "ebay_seller_name")
    var sellerName: String

    @Field(key: "ebay_keyword")
    var keyword: String

    @Parent(key: "seller_id")
    var seller: Seller

    @OptionalField(key: "custom_name")
    var customName: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?

    @Field(key: "current_response")
    var response: EbayItemSearchResponse

    @OptionalField(key: "scan_interval")
    var scanInterval: Int?

    @Field(key: "is_enabled")
    var isEnabled: Bool

    init() { }

    init(sellerName: String,
         keyword: String,
         sellerID: Seller.IDValue,
         customName: String? = nil,
         response: EbayItemSearchResponse,
         scanInterval: Int = 5) {
        self.sellerName = sellerName
        self.$seller.id = sellerID
        self.keyword = keyword
        self.customName = customName
        self.response = response
        self.scanInterval = scanInterval
        self.isEnabled = true
    }
}

extension SellerSellerSubscription: Parameter { }
