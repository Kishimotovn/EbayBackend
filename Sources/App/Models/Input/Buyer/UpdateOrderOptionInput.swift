//
//  File.swift
//  
//
//  Created by Phan Tran on 28/05/2020.
//

import Foundation
import Vapor

struct UpdateOrderOptionInput: Content {
    var orderOptionID: OrderOption.IDValue
}
