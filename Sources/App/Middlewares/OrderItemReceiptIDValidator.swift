//
//  File.swift
//  
//
//  Created by Phan Tran on 29/05/2020.
//

import Foundation
import Vapor
import Fluent

struct OrderItemReceiptIDValidator: Middleware {
    func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        guard
            let orderItemID = request.parameters.get(OrderItem.parameter, as: OrderItem.IDValue.self),
            let orderItemReceiptID = request.parameters.get(OrderItemReceipt.parameter, as: OrderItemReceipt.IDValue.self)
        else {
            return next.respond(to: request)
        }

        return request
            .orderItemReceipts
            .find(orderItemID: orderItemID,
                  orderItemReceiptID: orderItemReceiptID)
            .flatMap { receipt in
                if receipt != nil {
                    return next.respond(to: request)
                }

                return request.eventLoop.makeFailedFuture(Abort(.badRequest))
        }
    }
}
