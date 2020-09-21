//
//  File.swift
//  
//
//  Created by Phan Tran on 18/09/2020.
//

import Foundation
import Vapor

struct SearchEbayItemsBySellerInput: Content {
    var seller: String
    var keyword: String
    var itemOffset: String
}
