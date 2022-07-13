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
    var state: TrackedItem.State
    var sellerNote: String?
}

extension CreateMultipleTrackedItemInput {
    func trackedItem(by sellerID: Seller.IDValue) -> [TrackedItem] {
        return self.trackingNumbers.map {
            let importID = "manual-\(self.state)-\(Date().formatted(.iso8601))"
            let trail = TrackedItem.StateTrail(state: self.state, importID: importID)

            return TrackedItem(sellerID: sellerID,
                  trackingNumber: $0,
                  stateTrails: [trail],
                  sellerNote: self.sellerNote ?? "",
                  importIDs: [importID]
            )
        }
    }
}

extension CreateMultipleTrackedItemInput: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("trackingNumbers", as: [String].self, is: !.empty)
    }
}
