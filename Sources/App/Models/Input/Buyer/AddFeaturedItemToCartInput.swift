//
//  File.swift
//  
//
//  Created by Phan Tran on 18/09/2020.
//

import Foundation
import Vapor

struct AddFeaturedItemToCardInput: Content {
    var featuredItemID: SellerItemFeatured.IDValue
}
