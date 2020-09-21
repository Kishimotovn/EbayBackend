//
//  File.swift
//  
//
//  Created by Phan Tran on 18/09/2020.
//

import Foundation
import Vapor

struct EbayAPIItemListOutput: Content {
    var items: [EbayAPIItemOutput]
    var offset: Int
    var limit: Int
    var total: Int
}
