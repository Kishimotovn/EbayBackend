//
//  File.swift
//  
//
//  Created by Phan Tran on 25/10/2020.
//

import Foundation
import Vapor
import Fluent

struct SellerSubcriptionController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let groupedRoutes = routes.grouped("sellerSubscriptions")

        groupedRoutes.get(use: getAllHandler)
        groupedRoutes.post(use: createHandler)
        groupedRoutes.delete(SellerSellerSubscription.parameterPath, use: deleteHandler)
        groupedRoutes.put(SellerSellerSubscription.parameterPath, use: updateHandler)
    }

    private func updateHandler(request: Request) throws -> EventLoopFuture<SellerSellerSubscription> {
        guard let _ = request.application.masterSellerID else {
            throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
        }

        guard let subscriptionID = request.parameters.get(SellerSellerSubscription.parameter, as: SellerSellerSubscription.IDValue.self) else {
                throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
        }
        let input = try request.content.decode(UpdateSellerSubscriptionInput.self)

        return request.sellerSubscriptions.find(subscriptionID: subscriptionID)
            .unwrap(or: Abort(.badRequest, reason: "Yêu cầu không hợp lệ"))
            .flatMap { subscription in
                if let customName = input.customName {
                    subscription.customName = customName
                }
                if let scanInterval = input.scanInterval {
                    subscription.scanInterval = scanInterval
                }
                return request.sellerSubscriptions.save(subscription: subscription)
                    .transform(to: subscription)
            }
    }

    private func getAllHandler(request: Request) throws -> EventLoopFuture<[SellerSellerSubscription]> {
        guard let masterSellerID = request.application.masterSellerID else {
            throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
        }

        return request.sellerSubscriptions.find(sellerID: masterSellerID)
    }

    private func createHandler(request: Request) throws -> EventLoopFuture<SellerSellerSubscription> {
        guard let masterSellerID = request.application.masterSellerID else {
            throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
        }

        let input = try request.content.decode(CreateSellerSubscriptionInput.self)
        let initialResponse = EbayItemSearchResponse(itemSummaries: nil, offset: 0, limit: 0, total: 0)
        
        let subscription = SellerSellerSubscription(sellerName: input.sellerName, keyword: input.keyword, sellerID: masterSellerID, response: initialResponse)

        return request.sellerSubscriptions.save(subscription: subscription).transform(to: subscription)
    }

    private func deleteHandler(request: Request) throws -> EventLoopFuture<HTTPResponseStatus> {
        guard let _ = request.application.masterSellerID else {
            throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
        }

        guard let subscriptionID = request.parameters.get(SellerSellerSubscription.parameter, as: SellerSellerSubscription.IDValue.self) else {
                throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
        }
        
        return request.sellerSubscriptions.delete(subscriptionID: subscriptionID)
            .transform(to: .ok)
    }
}
