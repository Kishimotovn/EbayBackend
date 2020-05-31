//
//  File.swift
//  
//
//  Created by Phan Tran on 30/05/2020.
//

import Foundation
import Vapor

struct EbayAppID: StorageKey {
    typealias Value = String
}

extension Application {
    var ebayAppID: String? {
        get { self.storage[EbayAppID.self] }
        set { self.storage[EbayAppID.self] = newValue }
    }
}
