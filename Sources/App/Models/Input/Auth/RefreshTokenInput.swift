//
//  File.swift
//  
//
//  Created by Phan Tran on 19/05/2020.
//

import Foundation
import Vapor

struct RefreshTokenInput: Content {
    var refreshToken: String
}
