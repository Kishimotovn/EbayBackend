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
    var state: TrackedItem.State
    var sellerNote: String?
}

extension CreateTrackedItemInput {
    func trackedItem(by sellerID: Seller.IDValue) -> TrackedItem {
        let importID = "manual-\(self.state)-\(Date().formatted(.iso8601))"
        let trail = TrackedItem.StateTrail(state: self.state, importID: importID)

        return .init(
            sellerID: sellerID,
            trackingNumber: self.trackingNumber,
            stateTrails: [trail],
            sellerNote: self.sellerNote ?? "",
            importIDs: [importID]
        )
    }
}

extension CreateTrackedItemInput: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("trackingNumber", as: String.self, is: !.empty)
    }
}
