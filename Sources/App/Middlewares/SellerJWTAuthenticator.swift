//
//  File.swift
//  
//
//  Created by Phan Tran on 28/05/2020.
//

import Foundation
import Vapor
import JWT

struct SellerJWTAuthenticator: JWTAuthenticator {
    typealias Payload = Seller.AccessTokenPayload

    func authenticate(jwt: Seller.AccessTokenPayload, for request: Request) -> EventLoopFuture<Void> {
        guard let sellerID = UUID.init(jwt.sub.value) else {
            return request.eventLoop.makeFailedFuture(Abort(.unauthorized, reason: "Yêu cầu không hợp lệ"))
        }

        return request.sellers
            .find(id: sellerID)
            .flatMapThrowing
            {
                guard let user = $0 else {
                    return
                }
                request.auth.login(user)
            }
    }
}
