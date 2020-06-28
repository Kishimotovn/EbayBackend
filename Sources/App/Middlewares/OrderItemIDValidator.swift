//
//  File.swift
//  
//
//  Created by Phan Tran on 28/05/2020.
//

import Foundation
import Vapor
import Fluent

struct OrderItemIDValidator: Middleware {
    func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        guard
            let orderID = request.parameters.get(Order.parameter, as: Order.IDValue.self),
            let orderItemID = request.parameters.get(OrderItem.parameter, as: OrderItem.IDValue.self)
        else {
            return next.respond(to: request)
        }

        return request
            .orderItems
            .find(orderID: orderID, orderItemID: orderItemID)
            .flatMap { item in
                if item != nil {
                    return next.respond(to: request)
                }

                return request.eventLoop.makeFailedFuture(Abort(.badRequest, reason: "Yêu cầu không hợp lệ"))
        }
    }
}
