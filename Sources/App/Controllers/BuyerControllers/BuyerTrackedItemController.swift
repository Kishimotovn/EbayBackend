//
//  File.swift
//  
//
//  Created by Phan Anh Tran on 24/01/2022.
//

import Foundation
import Vapor
import Fluent
import SQLKit

struct BuyerTrackedItemController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let groupedRoutes = routes.grouped("buyerTrackedItems")

		groupedRoutes.get("packingRequest", use: getPackingRequestHandler)
        groupedRoutes.post("search", use: searchForTrackingItemsHandler)

        groupedRoutes.group(BuyerJWTAuthenticator()) { buyerOrNotRoutes in
        }

        let buyerProtectedRoutes = groupedRoutes
            .grouped(BuyerJWTAuthenticator())
            .grouped(Buyer.guardMiddleware())

        buyerProtectedRoutes.get("", use: getBuyerTrackedItemsHandler)
        buyerProtectedRoutes.get("count", use: getBuyerTrackedItemCountHandler)
        buyerProtectedRoutes.post("register", use: registerMultipleItemHandler)
        buyerProtectedRoutes.delete(use: deleteMultipleItemsHandler)
        buyerProtectedRoutes.patch(use: updateMultipleItemsHandler)
        buyerProtectedRoutes.patch(BuyerTrackedItem.parameterPath, use: updateBuyerTrackedItemHandler)
    }

	private func getPackingRequestHandler(request: Request) async throws -> String {
		let input = try request.query.decode(GetPackingRequestInput.self)

		guard let item = try await BuyerTrackedItemLinkView.query(on: request.db)
			.filter(\.$trackedItemTrackingNumber == input.trackingNumber)
			.with(\.$buyerTrackedItem)
			.first() else {
			return ""
		}

		return item.buyerTrackedItem.packingRequest
	}

    private func getBuyerTrackedItemCountHandler(request: Request) async throws -> BuyerTrackedItemCountOutput {
        let buyer = try request.auth.require(Buyer.self)
        let buyerID = try buyer.requireID()
        let input = try request.query.decode(GetBuyerTrackedItemInput.self)
        
        let states: [TrackedItem.State] = [.receivedAtUSWarehouse, .flyingBack, .receivedAtVNWarehouse]
        
        let counts = try await states.asyncMap { state -> Int in
            let query = BuyerTrackedItem.query(on: request.db)
                .filter(\.$buyer.$id == buyerID)
                .join(BuyerTrackedItemLinkView.self, on: \BuyerTrackedItem.$id == \BuyerTrackedItemLinkView.$buyerTrackedItem.$id)
                .join(TrackedItemActiveState.self, on: \TrackedItemActiveState.$id == \BuyerTrackedItemLinkView.$trackedItem.$id)
                .filter(TrackedItemActiveState.self, \.$state == state)
            
            if let searchString = input.searchString {
                query.group(.or) { builder in
                    builder.filter(.sql(raw: "\(BuyerTrackedItem.schema).tracking_number"), .custom("~*"), .bind("^.*(\(searchString))$"))
                    builder.filter(.sql(raw: "\(BuyerTrackedItem.schema).note"), .custom("~*"), .bind(searchString))
                }
            }
            
            if let fromDate = input.fromDate {
                if state == .receivedAtUSWarehouse {
                    query.filter(TrackedItemActiveState.self, \.$receivedAtUSAt >= fromDate)
                }
                if state == .flyingBack {
                    query.filter(TrackedItemActiveState.self, \.$flyingBackAt >= fromDate)
                }
                if state == .receivedAtVNWarehouse {
                    query.filter(TrackedItemActiveState.self, \.$receivedAtVNAt >= fromDate)
                }
            }

            if let toDate = input.toDate {
                if state == .receivedAtUSWarehouse {
                    query.filter(TrackedItemActiveState.self, \.$receivedAtUSAt < toDate)
                }
                if state == .flyingBack {
                    query.filter(TrackedItemActiveState.self, \.$flyingBackAt < toDate)
                }
                if state == .receivedAtVNWarehouse {
                    query.filter(TrackedItemActiveState.self, \.$receivedAtVNAt < toDate)
                }
            }

            return try await query.count()
        }

        return .init(receivedAtUSWarehouseCount: counts[0],
                     flyingBackCount: counts[1],
                     receivedAtVNWarehouseCount: counts[2])
    }
    
    private func updateMultipleItemsHandler(request: Request) async throws -> [BuyerTrackedItemOutput] {
        let buyer = try request.auth.require(Buyer.self)
        let buyerID = try buyer.requireID()

		let packingRequestLeft = buyer.packingRequestLeft

        let input = try request.content.decode(UpdateMultipleTrackedItemsInput.self)
		if !input.sharedPackingRequest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
			guard input.trackedItemIDs.count <= packingRequestLeft else {
				throw AppError.notEnoughPackingRequestLeft
			}
		}

        try await BuyerTrackedItem.query(on: request.db)
            .filter(\.$id ~~ input.trackedItemIDs)
            .filter(\.$buyer.$id == buyerID)
            .set(\.$note, to: input.sharedNote)
			.set(\.$packingRequest, to: input.sharedPackingRequest)
            .update()

        // TODO: LOOK AT THIS!
        let allItems = try await BuyerTrackedItem.query(on: request.db)
            .filter(\.$id ~~ input.trackedItemIDs)
            .filter(\.$buyer.$id == buyerID)
            .all()

        let targetTrackedNumbers = allItems.map(\.trackingNumber)
        let allTrackedItems = try await request.trackedItems.find(filter: .init(trackingNumbers: targetTrackedNumbers)).get()

        return allItems.map {
            $0.output(with: allTrackedItems)
        }
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

    
    // some comment
    private func getBuyerTrackedItemsHandler(request: Request) async throws -> GetBuyerTrackedItemPageOutput {
        let buyer = try request.auth.require(Buyer.self)
        let buyerID = try buyer.requireID()
        let input = try request.query.decode(GetBuyerTrackedItemInput.self)

        let query = BuyerTrackedItem.query(on: request.db)
            .filter(\.$buyer.$id == buyerID)

        if let searchString = input.searchString {
            query.group(.or) { builder in
                builder.filter(.sql(raw: "\(BuyerTrackedItem.schema).tracking_number"), .custom("~*"), .bind("^.*(\(searchString))$"))
                builder.filter(.sql(raw: "\(BuyerTrackedItem.schema).note"), .custom("~*"), .bind(searchString))
            }
        }

        query
            .join(BuyerTrackedItemLinkView.self, on: \BuyerTrackedItemLinkView.$buyerTrackedItem.$id == \BuyerTrackedItem.$id, method: .left)
            .join(TrackedItem.self, on: \BuyerTrackedItemLinkView.$trackedItem.$id == \TrackedItem.$id, method: .left)
            .join(TrackedItemActiveState.self, on: \TrackedItemActiveState.$id == \TrackedItem.$id, method: .left)

        if input.filteredStates.isEmpty {
            query.filter(.sql(raw: "\(TrackedItemActiveState.schema).state IS NULL"))
        } else {
            query
                .filter(TrackedItemActiveState.self, \.$state ~~ input.filteredStates)
                .with(\.$trackedItems)
            
            if let fromDate = input.fromDate {
                query.group(.or) { builder in
                    if input.filteredStates.contains(.receivedAtUSWarehouse) {
                        builder.filter(TrackedItemActiveState.self, \.$receivedAtUSAt >= fromDate)
                    }
                    if input.filteredStates.contains(.flyingBack) {
                        builder.filter(TrackedItemActiveState.self, \.$flyingBackAt >= fromDate)
                    }
                    if input.filteredStates.contains(.receivedAtVNWarehouse) {
                        builder.filter(TrackedItemActiveState.self, \.$receivedAtVNAt >= fromDate)
                    }
                }
            }

            if let toDate = input.toDate {
                query.group(.or) { builder in
                    if input.filteredStates.contains(.receivedAtUSWarehouse) {
                        builder.filter(TrackedItemActiveState.self, \.$receivedAtUSAt < toDate)
                    }
                    if input.filteredStates.contains(.flyingBack) {
                        builder.filter(TrackedItemActiveState.self, \.$flyingBackAt < toDate)
                    }
                    if input.filteredStates.contains(.receivedAtVNWarehouse) {
                        builder.filter(TrackedItemActiveState.self, \.$receivedAtVNAt < toDate)
                    }
                }
            }
        }

        let page = try await query
            .sort(TrackedItemActiveState.self, \.$power, .ascending)
            .sort(TrackedItemActiveState.self, \.$stateUpdatedAt, .ascending)
            .paginate(for: request)
        
        let allOutput: [BuyerTrackedItemOutput]
        
        if input.filteredStates.isEmpty {
            allOutput = page.items.map {
                $0.output(with: nil)
            }
        } else {
            allOutput = try await page.items.asyncMap {
                return try await $0.output(in: request.db)
            }
        }

        return .init(
            items: allOutput,
            metadata: .init(
                page: page.metadata.page,
                per: page.metadata.per,
                total: page.metadata.total,
                pageCount: page.metadata.pageCount,
                searchString: input.searchString,
                filteredStates: input.filteredStates,
                fromDate: input.fromDate,
                toDate: input.toDate
            )
        )
    }

    private func registerMultipleItemHandler(request: Request) async throws -> [BuyerTrackedItem] {
        let buyer = try request.auth.require(Buyer.self)
        let buyerID = try buyer.requireID()
		
		let packingRequestLeft = buyer.packingRequestLeft

        let input = try request.content.decode(RegisterMultipleTrackedItemInput.self)
		if input.sharedPackingRequest?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
			guard input.trackingNumbers.count <= packingRequestLeft else {
				throw AppError.notEnoughPackingRequestLeft
			}
		}

        let buyerTrackedItems = try await request
            .buyerTrackedItems
            .find(filter: .init(buyerID: buyerID, trackingNumbers: input.trackingNumbers))
            .get()

        return try await request.db.transaction { transactionDB in
            try await buyerTrackedItems.delete(on: transactionDB)
            
            let items = input.trackingNumbers.map {
                return BuyerTrackedItem(
                    note: input.sharedNote ?? "",
					packingRequest: input.sharedPackingRequest ?? "",
                    buyerID: buyerID,
                    trackingNumber: $0.trimmingCharacters(in: .whitespacesAndNewlines)
				)
            }
            
            try await items.create(on: transactionDB)
			buyer.packingRequestLeft -= input.trackingNumbers.count
			try await buyer.save(on: transactionDB)

            let payload = PeriodicallyUpdateJob.Payload(refreshBuyerTrackedItemLinkView: true, refreshTrackedItemActiveStateView: false)
            
            try await request.queue.dispatch(PeriodicallyUpdateJob.self, payload)
            return items
        }
    }

    private func searchForTrackingItemsHandler(request: Request) async throws -> [TrackedItem] {
        guard let masterSellerID = request.application.masterSellerID else {
            throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
        }

        try SearchTrackedItemsInput.validate(content: request)
        let input = try request.content.decode(SearchTrackedItemsInput.self)

        guard !input.validTrackingNumbers().isEmpty else {
            return []
        }

        var foundTrackedItems = try await request.trackedItems
            .find(filter: .init(searchStrings: input.validTrackingNumbers()))
            .get()
        
        foundTrackedItems = foundTrackedItems.sorted { lhs, rhs in
            let lhsPower = lhs.state?.power ?? 0
            let rhsPower = rhs.state?.power ?? 0
            return lhsPower <= rhsPower
        }
        
        foundTrackedItems.forEach { item in
            if item.trackingNumber.count == 32 {
                item.trackingNumber.removeLast(4)
            }
            
            if let buyerProvidedTrackingNumber = input.validTrackingNumbers().first(where: {
                item.trackingNumber.hasSuffix($0)
            }) {
                item.trackingNumber = buyerProvidedTrackingNumber
            }
        }
        
        foundTrackedItems = try foundTrackedItems.grouped(by: { $0.trackingNumber.uppercased() }).compactMap {
            let values = $0.value.sorted(by: { lhs, rhs in
                let lhsPower = lhs.state?.power ?? 0
                let rhsPower = rhs.state?.power ?? 0
                return lhsPower >= rhsPower
            })

            guard let value = values.first else { return nil }
            return value
        }

        let foundTrackingNumbers = Set(foundTrackedItems.map(\.trackingNumber).map({ $0.uppercased() }))
        let inputSet = Set(input.validTrackingNumbers().map({ $0.uppercased() }))

        let notFoundSet = inputSet.subtracting(foundTrackingNumbers)
        let notFoundItems = notFoundSet.map { trackingNumber in
            return TrackedItem.init(sellerID: masterSellerID, trackingNumber: trackingNumber, stateTrails: [], sellerNote: "", importIDs: [])
        }

        var items = notFoundItems
        items.append(contentsOf: foundTrackedItems)
        return items
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
				return request.db.transaction { db in
					if let note = input.note, note != buyerTrackedItem.note {
						buyerTrackedItem.note = note
					}
					
					if let packingRequest = input.packingRequest, packingRequest != buyerTrackedItem.packingRequest {
						guard buyer.packingRequestLeft > 0 else {
							return db.eventLoop.makeFailedFuture(AppError.notEnoughPackingRequestLeft)
						}
						
						buyer.packingRequestLeft -= 1
						buyerTrackedItem.packingRequest = packingRequest
					}
					
					return [
						buyer.save(on: db),
						buyerTrackedItem.save(on: db)
					].flatten(on: db.eventLoop)
					.transform(to: buyerTrackedItem)
				}
            }
    }
}

extension SiblingsProperty {
    public func attachOverride(
        fromID: From.IDValue,
        _ to: To,
        method: AttachMethod,
        on database: Database,
        override edit: @Sendable @escaping (Through) -> () = { _ in }
    ) async throws {
        try await self.attachOverride(fromID: fromID, to, method: method, on: database, override: edit).get()
    }

    public func attachOverride(
        fromID: From.IDValue,
        _ to: To,
        method: AttachMethod,
        on database: Database,
        override edit: @Sendable @escaping (Through) -> () = { _ in }
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
