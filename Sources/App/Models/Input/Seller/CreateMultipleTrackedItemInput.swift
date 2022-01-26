//
//  File.swift
//
//
//  Created by Phan Anh Tran on 24/01/2022.
//

import Foundation
import Vapor

struct CreateMultipleTrackedItemInput: Content {
    var trackingNumbers: [String]
}

extension CreateMultipleTrackedItemInput {
    func trackedItem(by sellerID: Seller.IDValue) -> [TrackedItem] {
        return self.trackingNumbers.map {
            .init(sellerID: sellerID,
                  trackingNumber: $0,
                  state: .receivedAtWarehouse,
                  sellerNote: "")
        }
    }
}

extension CreateMultipleTrackedItemInput: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("trackingNumbers", as: [String].self, is: !.empty)
    }
}
