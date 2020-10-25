//
//  File.swift
//  
//
//  Created by Phan Tran on 25/10/2020.
//

import Foundation
import Vapor

struct UpdateSellerSubscriptionInput: Content {
    var scanInterval: Int?
    var customName: String?
}
