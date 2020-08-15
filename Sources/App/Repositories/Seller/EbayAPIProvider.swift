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

struct EbayAppSecret: StorageKey {
    typealias Value = String
}

struct SecretIndex: StorageKey {
    typealias Value = Int
}

extension Application {
    var ebayAppID: String? {
        get { self.storage[EbayAppID.self] }
        set { self.storage[EbayAppID.self] = newValue }
    }

    var ebayAppSecret: String? {
        get { self.storage[EbayAppSecret.self] }
        set { self.storage[EbayAppSecret.self] = newValue }
    }

    var secretIndex: Int {
        get {
            self.storage[SecretIndex.self] ?? 0
        }
        set {
            self.storage[SecretIndex.self] = newValue
        }
    }
}
