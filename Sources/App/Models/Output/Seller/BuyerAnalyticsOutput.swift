//
//  File.swift
//  
//
//  Created by Phan Tran on 30/05/2020.
//

import Foundation
import Vapor

struct BuyerAnalyticsOutput: Content {
    var id: Buyer.IDValue
    var index: Int
    var username: String
    var email: String
    var joinDate: Date
    var orderCount: Int
    var totalRevenue: Int?
    var avgRate: Double?
}
