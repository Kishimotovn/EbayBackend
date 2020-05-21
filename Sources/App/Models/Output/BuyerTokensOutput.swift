//
//  File.swift
//  
//
//  Created by Phan Tran on 19/05/2020.
//

import Foundation
import Vapor

struct BuyerTokensOutput: Content {
    var refreshToken: String
    var accessToken: String
    var expiredAt: Date

    init(refreshToken: String, accessToken: String, expiredAt: Date) {
        self.refreshToken = refreshToken
        self.accessToken = accessToken
        self.expiredAt = expiredAt
    }
}
