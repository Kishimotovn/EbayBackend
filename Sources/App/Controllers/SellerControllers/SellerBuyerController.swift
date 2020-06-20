//
//  File.swift
//  
//
//  Created by Phan Tran on 17/06/2020.
//

import Foundation
import Vapor
import Fluent

struct SellerBuyerController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let groupedRoutes = routes.grouped("sellerBuyers")
        
        groupedRoutes.put(Buyer.parameterPath, "verify", use: verifyBuyerHandler)
    }

    private func verifyBuyerHandler(request: Request) throws -> EventLoopFuture<Buyer> {
        guard let buyerID = request.parameters.get(Buyer.parameter, as: Buyer.IDValue.self) else {
            throw Abort(.badRequest)
        }

        return request.buyers
            .find(buyerID: buyerID)
            .unwrap(or: Abort(.badRequest))
            .flatMap { buyer in
                buyer.verifiedAt = Date()
                return request.buyers
                    .save(buyer: buyer)
                    .transform(to: buyer)
        }.flatMap { (buyer: Buyer) in
                return request
                    .orders
                    .getWaitingForBuyerVerificationOrders(buyerID: buyerID)
                    .flatMap { orders -> EventLoopFuture<Void> in
                        return orders.map { order in
                            order.orderRegisteredAt = Date()
                            order.state = .registered
                            return request
                                .orders
                                .save(order: order)
                                .tryFlatMap {
                                    return try request.emails.sendOrderUpdateEmail(for: order)
                            }
                        }.flatten(on: request.eventLoop)
                    }
                .transform(to: buyer)
            }
        }
}
