//
//  File.swift
//  
//
//  Created by Phan Anh Tran on 24/01/2022.
//

import Foundation
import Vapor

struct CreateTrackedItemInput: Content {
    var trackingNumber: String
    var sellerNote: String?
}

extension CreateTrackedItemInput {
    func trackedItem(by sellerID: Seller.IDValue) -> TrackedItem {
        .init(sellerID: sellerID,
              trackingNumber: self.trackingNumber,
              state: .receivedAtWarehouse,
              sellerNote: self.sellerNote ?? "")
    }
}

extension CreateTrackedItemInput: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("trackingNumber", as: String.self, is: !.empty)
    }
}
