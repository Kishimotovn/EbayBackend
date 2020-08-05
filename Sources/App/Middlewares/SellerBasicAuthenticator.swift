//
//  File.swift
//  
//
//  Created by Phan Tran on 04/08/2020.
//

import Foundation
import Vapor
import Fluent

struct SellerBasicAuthenticator: BasicAuthenticator {
    func authenticate(basic: BasicAuthorization, for request: Request) -> EventLoopFuture<Void> {
        Seller.query(on: request.db)
            .group(.or) { builder in
                builder.filter(\.$name == basic.username)
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
