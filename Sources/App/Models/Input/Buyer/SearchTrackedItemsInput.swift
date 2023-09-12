//
//  File.swift
//  
//
//  Created by Phan Anh Tran on 25/01/2022.
//

import Foundation
import Vapor

struct SearchTrackedItemsInput: Content {
    let trackingNumbers: [String]
}

extension SearchTrackedItemsInput {
    func validTrackingNumbers() -> [String] {
		return self.trackingNumbers.compactMap { $0.requireValidTrackingNumber() }
    }
}

extension SearchTrackedItemsInput: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("trackingNumbers", as: [String].self, is: !.empty)
    }
}
