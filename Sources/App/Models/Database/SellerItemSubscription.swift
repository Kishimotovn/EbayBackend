//
//  File.swift
//  
//
//  Created by Phan Tran on 13/06/2020.
//

import Foundation
import Vapor
import Fluent

final class SellerItemSubscription: Model, @unchecked Sendable, Content {
    static let schema: String = "seller_item_subscription"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "seller_id")
    var seller: Seller

    @Parent(key: "item_id")
    var item: Item

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?

    @OptionalField(key: "scan_interval")
    var scanInterval: Int?

    @OptionalField(key: "custom_name")
    var customName: String?

    @Field(key: "is_enabled")
    var isEnabled: Bool

    init() { }

    init(sellerID: Seller.IDValue,
         itemID: Item.IDValue,
         scanInterval: Int = 5) {
        self.$seller.id = sellerID
        self.$item.id = itemID
        self.scanInterval = scanInterval
        self.isEnabled = true
    }
}

extension SellerItemSubscription: Parameter { }
