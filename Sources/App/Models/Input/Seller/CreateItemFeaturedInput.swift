//
//  File.swift
//  
//
//  Created by Phan Tran on 18/09/2020.
//

import Foundation
import Vapor

struct CreateItemFeaturedInput: Content {
    var items: [ItemFeaturedInput]
}

struct ItemFeaturedInput: Content {
    var itemID: String
    var name: String
    var imageURL: String
    var itemURL: String
    var condition: String?
    var shippingPrice: Int
    var originalPrice: Int
    var sellerName: String?
    var sellerFeedbackCount: Int?
    var sellerScore: Double?
    var itemEndDate: Date?
    var furtherDiscountAmount: Int?
    var volumeDiscounts: [VolumeDiscount]?
    var furtherDiscountDetected: Bool
}
