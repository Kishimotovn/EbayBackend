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
        
        groupedRoutes.get(Buyer.parameterPath, use: getBuyerHandler)
        groupedRoutes.get(Buyer.parameterPath, "warehouses", use: getBuyerWarehousesHandler)
        groupedRoutes.put(Buyer.parameterPath, "verify", use: verifyBuyerHandler)
		groupedRoutes.put(Buyer.parameterPath, "packingRequest", use: updateBuyerPackingRequestHandler)
    }

    private func getBuyerHandler(request: Request) throws -> EventLoopFuture<Buyer> {
        guard let buyerID = request.parameters.get(Buyer.parameter, as: Buyer.IDValue.self) else {
            throw Abort(.badRequest, reason: "Invalid Buyer ID")
        }

        return request
            .buyers
            .find(buyerID: buyerID)
            .unwrap(or: Abort(.badRequest, reason: "Invalid Buyer ID"))
    }

    private func getBuyerWarehousesHandler(request: Request) throws -> EventLoopFuture<[BuyerWarehouseAddress]> {
        guard let buyerID = request.parameters.get(Buyer.parameter, as: Buyer.IDValue.self) else {
            throw Abort(.badRequest, reason: "Invalid Buyer ID")
        }

        return request
            .buyers
            .find(buyerID: buyerID)
            .unwrap(or: Abort(.badRequest, reason: "Invalid Buyer ID"))
            .flatMap { buyer in
                return buyer
                    .$buyerWarehouseAddresses
                    .load(on: request.db)
                    .flatMap {
                        return buyer
                            .buyerWarehouseAddresses
                            .map {
                                return request
                                    .buyerWarehouseAddresses
                                    .find(id: $0.id!)
                                    .unwrap(or: Abort(.notFound, reason: "Yêu cầu không hợp lệ"))
                            }.flatten(on: request.eventLoop)
                }
        }
    }

	private func updateBuyerPackingRequestHandler(request: Request) async throws -> Int {
		struct Input: Content {
			var packingRequestLeft: Int
		}
		
		guard let buyerID = request.parameters.get(Buyer.parameter, as: Buyer.IDValue.self) else {
			throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
		}
		let input = try request.content.decode(Input.self)
		
		let buyer = try await request.buyers
			.find(buyerID: buyerID)
			.unwrap(or: Abort(.badRequest, reason: "Yêu cầu không hợp lệ"))
			.get()
		
		buyer.packingRequestLeft = input.packingRequestLeft
		try await buyer.save(on: request.db)
		
		return buyer.packingRequestLeft
	}

    private func verifyBuyerHandler(request: Request) throws -> EventLoopFuture<Buyer> {
        guard let buyerID = request.parameters.get(Buyer.parameter, as: Buyer.IDValue.self) else {
            throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
        }

        return request.buyers
            .find(buyerID: buyerID)
            .unwrap(or: Abort(.badRequest, reason: "Yêu cầu không hợp lệ"))
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
