//
//  File.swift
//  
//
//  Created by Phan Tran on 25/10/2020.
//

import Foundation
import Vapor

struct CreateSellerSubscriptionInput: Content {
    var sellerName: String
    var keyword: String
}

extension CreateSellerSubscriptionInput: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("sellerName", as: String.self, is: !.empty)
        validations.add("keyword", as: String.self, is: !.empty)
    }
}
