//
//  File.swift
//  
//
//  Created by Phan Tran on 19/06/2020.
//

import Foundation
import Vapor

struct ValidateResetPasswordTokenInput: Content {
    var token: String
}
