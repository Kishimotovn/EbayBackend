//
//  File.swift
//  
//
//  Created by Phan Anh Tran on 24/01/2022.
//

import Foundation
import Vapor
import Fluent

final class BuyerTrackedItem: Model, Content  {
    static var schema: String = "buyer_tracked_items"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "note")
    var note: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Parent(key: "buyer_id")
    var buyer: Buyer

    @Parent(key: "tracked_item_id")
    var trackedItem: TrackedItem

    init() { }

    init(
        note: String,
        buyerID: Buyer.IDValue,
        trackedItemID: TrackedItem.IDValue
    ) {
        self.note = note
        self.$buyer.id = buyerID
        self.$trackedItem.id = trackedItemID
    }
}

extension BuyerTrackedItem: Parameter { }
