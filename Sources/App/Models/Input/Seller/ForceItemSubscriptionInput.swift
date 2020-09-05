//
//  File.swift
//  
//
//  Created by Phan Tran on 05/09/2020.
//

import Foundation
import Vapor

struct ForceItemSubscriptionInput: Content {
    var itemID: String
    var itemURL: String
}
