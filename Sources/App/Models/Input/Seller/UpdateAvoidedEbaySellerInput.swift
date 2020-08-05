//
//  File.swift
//  
//
//  Created by Phan Tran on 04/08/2020.
//

import Foundation
import Vapor

struct UpdateAvoidedEbaySellersInput: Content {
    var sellers: [String]
}
