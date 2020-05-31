//
//  File.swift
//  
//
//  Created by Phan Tran on 30/05/2020.
//

import Foundation
import Vapor

struct EbayAPIItemOutput: Content {
    var itemID: String
    var name: String
    var imageURL: String
    var condition: String?
    var shippingPrice: Int
    var originalPrice: Int
    var sellerName: String?
    var sellerFeedbackCount: Int?
    var sellerScore: Double?
}