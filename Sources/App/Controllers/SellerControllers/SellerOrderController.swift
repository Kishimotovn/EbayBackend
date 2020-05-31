//
//  File.swift
//  
//
//  Created by Phan Tran on 28/05/2020.
//

import Foundation
import Vapor
import Fluent

struct SellerOrderController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let groupedRoutes = routes.grouped("sellerOrders")

        groupedRoutes.get("active", use: getActiveOrders)
        groupedRoutes.get("waitingForTracking", use: getWaitingForTrackingOrdersHandler)
        groupedRoutes.get("buyerAnalytics", use: getBuyerAnalyticsHandler)

        let validatedRoutes = groupedRoutes.grouped(OrderItemIDValidator())

        let restrictedRoutes = validatedRoutes
            .grouped(SellerUpdateOrderRestrictor())

        restrictedRoutes.post(Order.parameterPath, OrderItem.parameterPath, "receipts", use: createReceiptHandler)

        restrictedRoutes.group(OrderItemReceiptIDValidator()) { validated in
            validated.put(Order.parameterPath, OrderItem.parameterPath, "receipts", OrderItemReceipt.parameterPath, use: updateReceiptHandler)
        }
    }

    private func getBuyerAnalyticsHandler(request: Request) throws -> EventLoopFuture<[BuyerAnalyticsOutput]> {
        guard let masterSellerID = request.application.masterSellerID else {
            throw Abort(.unauthorized)
        }

        return request.sellerAnalytics.buyerAnalytics(sellerID: masterSellerID)
    }

    private func getWaitingForTrackingOrdersHandler(request: Request) throws -> EventLoopFuture<Page<Order>> {
        let pageRequest = try request.query.decode(PageRequest.self)
        guard let sellerID = request.application.masterSellerID else {
            throw Abort(.unauthorized)
        }

        return request
            .orders
            .getWaitingForTrackingOrders(sellerID: sellerID, pageRequest: pageRequest)
    }

    private func updateReceiptHandler(request: Request) throws -> EventLoopFuture<OrderItemReceipt> {
        guard let orderItemReceiptID = request.parameters.get(OrderItemReceipt.parameter, as: OrderItem.IDValue.self) else {
            throw Abort(.badRequest)
        }

        let input = try request.content.decode(UpdateOrderItemReceiptInput.self)
        return request
            .orderItemReceipts
            .find(id: orderItemReceiptID)
            .optionalFlatMap { receipt in
                receipt.imageURL = input.imageURL
                receipt.trackingNumber = input.trackingNumber
                receipt.resolvedQuantity = input.resolvedQuantity

                return request
                    .orderItemReceipts
                    .save(orderItemReceipt: receipt)
                    .transform(to: receipt)
            }
            .unwrap(or: Abort(.notFound))
    }

    private func createReceiptHandler(request: Request) throws -> EventLoopFuture<OrderItemReceipt> {
        guard let orderItemID = request.parameters.get(OrderItem.parameter, as: OrderItem.IDValue.self) else {
            throw Abort(.badRequest)
        }

        let input = try request.content.decode(CreateOrderItemReceiptInput.self)

        let receipt = OrderItemReceipt(
            orderItemID: orderItemID,
            imageURL: input.imageURL,
            trackingNumber: input.trackingNumber,
            resolvedQuantity: input.resolvedQuantity)

        return request
            .orderItemReceipts
            .save(orderItemReceipt: receipt)
            .transform(to: receipt)
    }

    private func getActiveOrders(request: Request) throws -> EventLoopFuture<Page<Order>> {
        let pageRequest = try request.query.decode(PageRequest.self)
        guard let sellerID = request.application.masterSellerID else {
            throw Abort(.unauthorized)
        }

        return request
            .orders
            .getActiveOrders(sellerID: sellerID, pageRequest: pageRequest)
    }
}
