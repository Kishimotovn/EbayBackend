//
//  File.swift
//  
//
//  Created by Phan Tran on 17/06/2020.
//

import Foundation
import Vapor

struct RequestResetPasswordInput: Content {
    var email: String
}
