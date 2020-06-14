//
//  File.swift
//  
//
//  Created by Phan Tran on 14/06/2020.
//

import Foundation
import Vapor

struct CreateItemSubscriptionInput: Content {
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
    var lastKnownAvailability: Bool?
}
