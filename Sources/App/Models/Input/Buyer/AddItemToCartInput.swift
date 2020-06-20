//
//  File.swift
//  
//
//  Created by Phan Tran on 25/05/2020.
//

import Foundation
import Vapor

struct AddItemToCartInput: Content {
    var itemID: String
    var name: String
    var imageURL: String
    var itemURL: String
    var quantity: Int
    var condition: String?
    var shippingPrice: Int
    var originalPrice: Int
    var sellerName: String?
    var sellerFeedbackCount: Int?
    var sellerScore: Double?
    var itemEndDate: Date?
    var furtherDiscountAmount: Int?
    var furtherDiscountDetected: Bool
}
