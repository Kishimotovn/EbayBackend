//
//  File.swift
//  
//
//  Created by Phan Tran on 28/05/2020.
//

import Foundation
import Vapor
import Fluent

struct SellerUpdateOrderRestrictor: Middleware {
    func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        if let orderID = request.parameters.get(Order.parameter, as: Order.IDValue.self) {
            guard let sellerID = request.application.masterSellerID else {
                return request.eventLoop.makeFailedFuture(Abort(.badRequest))
            }

            return request
                .orders
                .getCurrentActiveOrder(sellerID: sellerID)
                .flatMap { order in
                    if let currentActiveOrder = order {
                        if currentActiveOrder.id != orderID {
                            return request.eventLoop.makeFailedFuture(Abort(.badRequest))
                        }
                    }

                    return next.respond(to: request)
            }
        }

        return next.respond(to: request)
    }
}
