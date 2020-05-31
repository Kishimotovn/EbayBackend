//
//  Item.swift
//  
//
//  Created by Phan Tran on 23/05/2020.
//

import Foundation
import Fluent
import Vapor

final class Item: Model, Content {
    static var schema: String = "item"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "item_id")
    var itemID: String

    @OptionalField(key: "image_url")
    var imageURL: String?

    @OptionalField(key: "name")
    var name: String?

    @OptionalField(key: "condition")
    var condition: String?

    @Field(key: "shipping_price")
    var shippingPrice: Int

    @Field(key: "original_price")
    var originalPrice: Int

    @OptionalField(key: "seller_name")
    var sellerName: String?

    @OptionalField(key: "seller_feedback_count")
    var sellerFeedbackCount: Int?

    @OptionalField(key: "seller_score")
    var sellerScore: Double?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Siblings(through: OrderItem.self, from: \.$item, to: \.$order)
    var orders: [Order]

    init() { }

    init(itemID: String,
         imageURL: String? = nil,
         name: String? = nil,
         condition: String? = nil,
         shippingPrice: Int = 0,
         originalPrice: Int = 0,
         sellerName: String? = nil,
         sellerFeedbackCount: Int? = nil,
         sellerScore: Double? = nil) {
        self.itemID = itemID
        self.imageURL = imageURL
        self.name = name
        self.condition = condition
        self.shippingPrice = shippingPrice
        self.originalPrice = originalPrice
        self.sellerName = sellerName
        self.sellerFeedbackCount = sellerFeedbackCount
        self.sellerScore = sellerScore
    }
}
