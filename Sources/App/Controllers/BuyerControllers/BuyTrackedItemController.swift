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

        buyerProtectedRoutes.get("", use: getBuyerTrackedItemsHandler)
        buyerProtectedRoutes.post("register", use: registerMultipleItemHandler)
        buyerProtectedRoutes.delete(use: deleteMultipleItemsHandler)
        buyerProtectedRoutes.patch(use: updateMultipleItemsHandler)
        buyerProtectedRoutes.post(TrackedItem.parameterPath, "register", use: registerBuyerTrackedItemHandler)
        buyerProtectedRoutes.patch(BuyerTrackedItem.parameterPath, use: updateBuyerTrackedItemHandler)
    }
    
    private func updateMultipleItemsHandler(request: Request) async throws -> [BuyerTrackedItem] {
        let buyer = try request.auth.require(Buyer.self)
        let buyerID = try buyer.requireID()

        let input = try request.content.decode(UpdateMultipleTrackedItemsInput.self)

        try await BuyerTrackedItem.query(on: request.db)
            .filter(\.$id ~~ input.trackedItemIDs)
            .filter(\.$buyer.$id == buyerID)
            .set(\.$note, to: input.sharedNote)
            .update()

        return try await BuyerTrackedItem.query(on: request.db)
            .filter(\.$id ~~ input.trackedItemIDs)
            .filter(\.$buyer.$id == buyerID)
            .with(\.$trackedItem)
            .all()
    }

    private func deleteMultipleItemsHandler(request: Request) async throws -> HTTPResponseStatus {
        let buyer = try request.auth.require(Buyer.self)
        let buyerID = try buyer.requireID()

        let input = try request.content.decode(DeleteMultipleTrackedItemsInput.self)

        try await BuyerTrackedItem.query(on: request.db)
            .filter(\.$id ~~ input.trackedItemIDs)
            .filter(\.$buyer.$id == buyerID)
            .delete()

        return .ok
    }

    private func getBuyerTrackedItemsHandler(request: Request) async throws -> GetBuyerTrackedItemPageOutput {
        let buyer = try request.auth.require(Buyer.self)
        let buyerID = try buyer.requireID()
        let input = try request.query.decode(GetBuyerTrackedItemInput.self)

        let query = BuyerTrackedItem.query(on: request.db)
            .filter(\.$buyer.$id == buyerID)
            .join(parent: \.$trackedItem)
            .with(\.$trackedItem)
            .sort(\.$createdAt, .descending)

        if let searchString = input.searchString {
            query.filter(.sql(raw: "\(TrackedItem.schema).tracking_number"), .custom("ILIKE"), .bind("%\(searchString)"))
        }
        
        
        query.join(TrackedItemActiveState.self, on: \TrackedItemActiveState.$id == \TrackedItem.$id, method: .left)
        
        if input.filteredStates.isEmpty {
            query.filter(.sql(raw: "\(TrackedItemActiveState.schema).state IS NULL"))
        } else {
            query.filter(TrackedItemActiveState.self, \.$state ~~ input.filteredStates)
        }
        

        let page = try await query
            .paginate(for: request)

        return .init(
            items: page.items,
            metadata: .init(
                page: page.metadata.page,
                per: page.metadata.per,
                total: page.metadata.total,
                pageCount: page.metadata.pageCount,
                searchString: input.searchString,
                filteredStates: input.filteredStates
            )
        )
    }

    private func registerMultipleItemHandler(request: Request) async throws -> [BuyerTrackedItem] {
        let buyer = try request.auth.require(Buyer.self)
        let buyerID = try buyer.requireID()

        let input = try request.content.decode(RegisterMultipleTrackedItemInput.self)

        let trackedItems = try await request
            .trackedItems
            .find(filter: .init(ids: input.trackedItemIDs))
            .get()

        try await request.db.transaction { db in
            try await trackedItems.asyncForEach { trackedItem in
                try await buyer.$trackedItems.attachOverride(
                    fromID: buyerID,
                    trackedItem,
                    method: .ifNotExists,
                    on: db) { pivotItem in
                        pivotItem.note = input.sharedNote ?? ""
                    }
            }
        }

        let trackedItemIDs = trackedItems.compactMap(\.id)
        return try await request.buyerTrackedItems
            .find(filter: .init(buyerID: buyerID, trackedItemIDs: trackedItemIDs))
            .get()
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
                    return TrackedItem.init(sellerID: masterSellerID, trackingNumber: trackingNumber, stateTrails: [], sellerNote: "", importIDs: [])
                }

                return request.trackedItems.create(notFoundItems)
                    .transform(to: (notFoundItems, foundTrackedItems))
            }.map { notFoundItems, foundTrackedItems in
                var items = notFoundItems
                items.append(contentsOf: foundTrackedItems)
                return items
            }
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
    ) async throws {
        try await self.attachOverride(fromID: fromID, to, method: method, on: database, override: edit).get()
    }

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
