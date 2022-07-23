//
//  File.swift
//  
//
//  Created by Phan Tran on 28/06/2020.
//

import Foundation
import Vapor
import Fluent

struct BuyerBasicAuthenticator: BasicAuthenticator {
    func authenticate(basic: BasicAuthorization, for request: Request) -> EventLoopFuture<Void> {
        Buyer.query(on: request.db)
            .group(.or) { builder in
                builder.filter(\.$username == basic.username)
                builder.filter(\.$email == basic.username)
                builder.filter(\.$phoneNumber == basic.username)
            }
            .first()
            .flatMapThrowing
        {
            guard let user = $0 else {
                return
            }
            guard try user.verify(password: basic.password) else {
                return
            }
            request.auth.login(user)
        }
    }
}
