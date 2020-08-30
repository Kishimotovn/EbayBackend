//
//  File.swift
//  
//
//  Created by Phan Tran on 16/08/2020.
//

import Foundation
import Vapor

struct UpdateItemSubscriptionInput: Content {
    var scanInterval: Int?
    var customName: String?
}
