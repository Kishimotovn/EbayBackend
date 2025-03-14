//
//  File.swift
//  
//
//  Created by Phan Anh Tran on 24/01/2022.
//

import Foundation
import Vapor
import Fluent

final class BuyerTrackedItem: Model, @unchecked Sendable, Content  {
    static let schema: String = "buyer_tracked_items"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "note")
    var note: String

	@Field(key: "packing_request")
	var packingRequest: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Parent(key: "buyer_id")
    var buyer: Buyer

    @Field(key: "tracking_number")
    var trackingNumber: String

    @Siblings(through: BuyerTrackedItemLinkView.self, from: \.$buyerTrackedItem, to: \.$trackedItem)
    var trackedItems: [TrackedItem]

    init() { }

    init(
        note: String,
		packingRequest: String,
        buyerID: Buyer.IDValue,
        trackingNumber: String
    ) {
        self.note = note
        self.$buyer.id = buyerID
        self.trackingNumber = trackingNumber
		self.packingRequest = packingRequest
    }
}

extension BuyerTrackedItem: Parameter { }
