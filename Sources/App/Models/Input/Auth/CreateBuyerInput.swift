//
//  CreateBuyerInput.swift
//  
//
//  Created by Phan Tran on 19/05/2020.
//

import Foundation
import Vapor

struct CreateBuyerInput: Content {
    var username: String
    var email: String
    var password: String
    var confirmPassword: String
    var phoneNumber: String
}

extension CreateBuyerInput {
    func buyer() throws -> Buyer {
        return try Buyer(username: self.username.lowercased(),
                         passwordHash: Bcrypt.hash(self.password),
                         email: self.email.lowercased(),
                         phoneNumber: self.phoneNumber)
    }
}

extension CreateBuyerInput: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("username", as: String.self, is: !.empty)
        validations.add("email", as: String.self, is: .email)
        validations.add("password", as: String.self, is: .count(1...))
        validations.add("confirmPassword", as: String.self, is: .count(1...))
        validations.add("phoneNumber", as: String.self, is: !.empty)
    }
}
