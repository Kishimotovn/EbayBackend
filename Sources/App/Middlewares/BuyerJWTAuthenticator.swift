//
//  File.swift
//  
//
//  Created by Phan Tran on 19/05/2020.
//

import Foundation
import Vapor
import JWT

struct BuyerJWTAuthenticator: JWTAuthenticator {
    typealias Payload = Buyer.AccessTokenPayload

    func authenticate(jwt: Buyer.AccessTokenPayload, for request: Request) -> EventLoopFuture<Void> {
        guard let buyerID = UUID.init(jwt.sub.value) else {
            return request.eventLoop.makeFailedFuture(Abort(.unauthorized))
        }

        return request.buyers
            .find(buyerID: buyerID)
            .flatMapThrowing
            {
                guard let user = $0 else {
                    return
                }
                request.auth.login(user)
            }
    }
}
