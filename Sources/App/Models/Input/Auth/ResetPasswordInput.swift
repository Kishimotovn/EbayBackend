//
//  File.swift
//  
//
//  Created by Phan Tran on 18/06/2020.
//

import Foundation
import Vapor

struct ResetPasswordInput: Content {
    var resetPasswordToken: String
    var password: String
    var confirmPassword: String
}
