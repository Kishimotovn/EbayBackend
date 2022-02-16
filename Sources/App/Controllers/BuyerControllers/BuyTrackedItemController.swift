//
//  File.swift
//  
//
//  Created by Phan Anh Tran on 24/01/2022.
//

import Foundation
import Vapor
import Fluent

struct BuyerTrackedItemController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let groupedRoutes = routes.grouped("buyerTrackedItems")

        groupedRoutes.post("search", use: searchForTrackingItemsHandler)

        groupedRoutes.group(BuyerJWTAuthenticator()) { buyerOrNotRoutes in
        }
        
        let buyerProtectedRoutes = groupedRoutes
            .grouped(BuyerJWTAuthenticator())
            .grouped(Buyer.guardMiddleware())

        buyerProtectedRoutes.get(use: getPaginatedHandler)
        buyerProtectedRoutes.get("registered", use: getPaginatedRegisteredHandler)
        buyerProtectedRoutes.get("received", use: getPaginatedReceivedHandler)
        buyerProtectedRoutes.post("register", use: registerMultipleItemHandler)
        buyerProtectedRoutes.post(TrackedItem.parameterPath, "register", use: registerBuyerTrackedItemHandler)
        buyerProtectedRoutes.patch(BuyerTrackedItem.parameterPath, use: updateBuyerTrackedItemHandler)
    }

    private func registerMultipleItemHandler(request: Request) throws -> EventLoopFuture<[BuyerTrackedItem]> {
        let buyer = try request.auth.require(Buyer.self)
        let buyerID = try buyer.requireID()

        let input = try request.content.decode(RegisterMultipleTrackedItemInput.self)

        return request
            .trackedItems
            .find(filter: .init(ids: input.trackedItemIDs))
            .flatMap { trackedItems in
                return request.db.transaction { db in
                    return trackedItems.map { trackedItem in
                        return buyer.$trackedItems.attachOverride(
                            fromID: buyerID,
                            trackedItem,
                            method: .ifNotExists,
                            on: db) { pivotItem in
                                pivotItem.note = input.sharedNote ?? ""
                            }
                    }.flatten(on: db.eventLoop)
                }.transform(to: trackedItems)
            }.tryFlatMap { trackedItems in
                let trackedItemIDs = trackedItems.compactMap(\.id)
                return request.buyerTrackedItems
                    .find(filter: .init(buyerID: buyerID, trackedItemIDs: trackedItemIDs))
            }
    }

    private func searchForTrackingItemsHandler(request: Request) throws -> EventLoopFuture<[TrackedItem]> {
        guard let masterSellerID = request.application.masterSellerID else {
            throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
        }

        try SearchTrackedItemsInput.validate(content: request)
        let input = try request.content.decode(SearchTrackedItemsInput.self)
        
        guard !input.validTrackingNumbers().isEmpty else {
            return request.eventLoop.future([])
        }

        return request.trackedItems
            .find(filter: .init(searchStrings: input.validTrackingNumbers()))
            .flatMap { foundTrackedItems -> EventLoopFuture<([TrackedItem], [TrackedItem])> in
                let foundTrackingNumbers = foundTrackedItems.map(\.trackingNumber)
                let notFoundItems = input.validTrackingNumbers().filter { trackingNumber in
                    !foundTrackingNumbers.contains(where: { $0.hasSuffix(trackingNumber) })
                }.map { trackingNumber in
                    return TrackedItem.init(sellerID: masterSellerID, trackingNumber: trackingNumber, state: .registered, sellerNote: "")
                }
                
                return request.trackedItems.create(notFoundItems)
                    .transform(to: (notFoundItems, foundTrackedItems))
            }.map { notFoundItems, foundTrackedItems in
                var items = notFoundItems
                items.append(contentsOf: foundTrackedItems)
                return items
            }
    }

    private func getPaginatedHandler(request: Request) throws -> EventLoopFuture<Page<BuyerTrackedItem>> {
        let buyer = try request.auth.require(Buyer.self)
        let buyerID = try buyer.requireID()
        let pageRequest = try request.query.decode(PageRequest.self)
        struct QueryBody: Content {
            var state: TrackedItem.State?
        }
        let input = try request.query.decode(QueryBody.self)
        return request.buyerTrackedItems.paginated(filter: .init(buyerID: buyerID, states: [input.state].compactMap { $0} ), pageRequest: pageRequest)
    }

    private func getPaginatedRegisteredHandler(request: Request) throws -> EventLoopFuture<Page<BuyerTrackedItem>> {
        let buyer = try request.auth.require(Buyer.self)
        let buyerID = try buyer.requireID()
        let pageRequest = try request.query.decode(PageRequest.self)
        
        if pageRequest.per <= 0 {
            return request.buyerTrackedItems.find(filter: .init(buyerID: buyerID, states: [.registered]))
                .map { items in
                    return Page(items: items, metadata: .init(page: 1, per: -1, total: items.count))
                }
        } else {
            return request.buyerTrackedItems.paginated(filter: .init(buyerID: buyerID, states: [.registered]), pageRequest: pageRequest)
        }
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
                return request.buyerTrackedItems.find(filter: .init(buyerID: buyerID, trackedItemIDs: [trackedItemID], limit: 1))
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

extension SiblingsProperty {
    public func attachOverride(
        fromID: From.IDValue,
        _ to: To,
        method: AttachMethod,
        on database: Database,
        override edit: @escaping (Through) -> () = { _ in }
    ) -> EventLoopFuture<Void> {
        switch method {
        case .always:
            return self.attach(to, on: database, edit)
        case .ifNotExists:
            return self.isAttached(to: to, on: database).flatMap { alreadyAttached in
                if alreadyAttached {
                    guard let toID = to.id else {
                        fatalError("Cannot check if siblings are attached to an unsaved model.")
                    }
                    return Through.query(on: database)
                        .filter(self.from.appending(path: \.$id) == fromID)
                        .filter(self.to.appending(path: \.$id) == toID)
                        .first()
                        .flatMap { existingPivot in
                            guard let pivot = existingPivot else {
                                return database.eventLoop.future()
                            }
                            edit(pivot)
                            return pivot.save(on: database)
                        }
                }

                return self.attach(to, on: database, edit)
            }
        }
    }
}
