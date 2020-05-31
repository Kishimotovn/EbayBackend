//
//  File.swift
//  
//
//  Created by Phan Tran on 28/05/2020.
//

import Foundation
import Vapor

struct CreateOrderItemReceiptInput: Content {
    var imageURL: String
    var resolvedQuantity: Int
    var trackingNumber: String?
}
