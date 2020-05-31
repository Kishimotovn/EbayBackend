//
//  File.swift
//  
//
//  Created by Phan Tran on 27/05/2020.
//

import Foundation
import Vapor

struct RearrangeItemOrderInput: Content {
    var newOrder: [OrderItem.IDValue]
}
