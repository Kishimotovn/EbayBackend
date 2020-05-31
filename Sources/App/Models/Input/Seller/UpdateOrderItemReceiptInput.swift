//
//  File.swift
//  
//
//  Created by Phan Tran on 29/05/2020.
//

import Foundation
import Vapor

struct UpdateOrderItemReceiptInput: Content {
    var imageURL: String
    var trackingNumber: String?
    var resolvedQuantity: Int
}
