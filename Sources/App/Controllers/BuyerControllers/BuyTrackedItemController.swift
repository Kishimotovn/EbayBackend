//
//  File.swift
//  
//
//  Created by Phan Anh Tran on 24/01/2022.
//

import Foundation
import Vapor
import Fluent
import CloudKit

struct BuyerTrackedItemController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let groupedRoutes = routes.grouped("buyerTrackedItems")

        groupedRoutes.post("search", use: searchForTrackingItemsHandler)

        groupedRoutes.group(BuyerJWTAuthenticator()) { buyerOrNotRoutes in
        }
        
        let buyerProtectedRoutes = groupedRoutes
            .grouped(BuyerJWTAuthenticator())
            .grouped(Buyer.guardMiddleware())

        buyerProtectedRoutes.get("registered", use: getPaginatedRegisteredHandler)
        buyerProtectedRoutes.get("received", use: getPaginatedReceivedHandler)
        buyerProtectedRoutes.post(TrackedItem.parameterPath, "register", use: registerBuyerTrackedItemHandler)
        buyerProtectedRoutes.patch(BuyerTrackedItem.parameterPath, use: updateBuyerTrackedItemHandler)
    }

    private func searchForTrackingItemsHandler(request: Request) throws -> EventLoopFuture<[TrackedItem]> {
        try SearchTrackedItemsInput.validate(content: request)
        let input = try request.content.decode(SearchTrackedItemsInput.self)

        return request.trackedItems
            .find(filter: .init(searchStrings: input.validTrackingNumbers()))
    }

    private func getPaginatedRegisteredHandler(request: Request) throws -> EventLoopFuture<Page<BuyerTrackedItem>> {
        let buyer = try request.auth.require(Buyer.self)
        let buyerID = try buyer.requireID()
        let pageRequest = try request.query.decode(PageRequest.self)

        return request.buyerTrackedItems.paginated(filter: .init(buyerID: buyerID, states: [.registered]), pageRequest: pageRequest)
    }

    private func getPaginatedReceivedHandler(request: Request) throws -> EventLoopFuture<Page<BuyerTrackedItem>> {
        let buyer = try request.auth.require(Buyer.self)
        let buyerID = try buyer.requireID()
        let pageRequest = try request.query.decode(PageRequest.self)

        return request.buyerTrackedItems.paginated(filter: .init(buyerID: buyerID, states: [.receivedAtWarehouse]), pageRequest: pageRequest)
    }

    private func registerBuyerTrackedItemHandler(request: Request) throws -> EventLoopFuture<BuyerTrackedItem> {
        let buyer = try request.auth.require(Buyer.self)
        let buyerID = try buyer.requireID()

        guard let trackedItemID: TrackedItem.IDValue = request.parameters.get(TrackedItem.parameter) else {
            throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
        }
        
        return request
            .trackedItems
            .find(filter: .init(ids: [trackedItemID], limit: 1))
            .first()
            .unwrap(or: Abort(.badRequest, reason: "Yêu cầu không hợp lệ"))
            .flatMap { trackedItem in
                return buyer.$trackedItems.attach(trackedItem, method: .ifNotExists, on: request.db)
                    .transform(to: trackedItem)
            }.tryFlatMap { trackedItem in
                let trackedItemID = try trackedItem.requireID()
                return request.buyerTrackedItems.find(filter: .init(buyerID: buyerID, trackedItemID: trackedItemID, limit: 1))
                    .first()
                    .unwrap(or: Abort(.badRequest, reason: "Yêu cầu không hợp lệ"))
            }
    }

    private func updateBuyerTrackedItemHandler(request: Request) throws -> EventLoopFuture<BuyerTrackedItem> {
        let buyer = try request.auth.require(Buyer.self)
        let buyerID = try buyer.requireID()

        guard let trackedItemID: BuyerTrackedItem.IDValue = request.parameters.get(BuyerTrackedItem.parameter) else {
            throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
        }
        
        let input = try request.content.decode(UpdateBuyerTrackedItemInput.self)

        return request
            .buyerTrackedItems
            .find(filter: .init(ids: [trackedItemID], buyerID: buyerID, limit: 1))
            .first()
            .unwrap(or: Abort(.badRequest, reason: "Yêu cầu không hợp lệ"))
            .flatMap { buyerTrackedItem in
                if let note = input.note, note != buyerTrackedItem.note {
                    buyerTrackedItem.note = note
                }

                return request.buyerTrackedItems.save(buyerTrackedItem)
                    .transform(to: buyerTrackedItem)
            }
    }
}
