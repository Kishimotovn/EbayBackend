//
//  File.swift
//  
//
//  Created by Phan Anh Tran on 24/01/2022.
//

import Foundation
import Vapor
import Fluent

struct SellerTrackedItemController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let groupedRoutes = routes.grouped("sellerTrackedItems")

        groupedRoutes.get(use: getPaginatedHandler)
        groupedRoutes.get("byPeriod", use: getByPeriodHandler)
        groupedRoutes.get("search", use: getByPeriodHandler)
        groupedRoutes.post(use: createHandler)
        groupedRoutes.post("multiple", use: createMultipleHandler)
        groupedRoutes.delete(TrackedItem.parameterPath, use: deleteHandler)
        groupedRoutes.delete("clearDay", use: clearDayHandler)
    }

    private func clearDayHandler(request: Request) throws -> EventLoopFuture<HTTPResponseStatus> {
        guard let masterSellerID = request.application.masterSellerID else {
            throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
        }

        struct QueryBody: Content {
            @ISO8601Date var date: Date
        }

        let input = try request.query.decode(QueryBody.self)

        return request.trackedItems
            .find(filter: .init(sellerID: masterSellerID, date: input.date))
            .flatMap { trackedItems -> EventLoopFuture<Void> in
                let trackedItemIDs = trackedItems.compactMap(\.id)
                guard !trackedItemIDs.isEmpty else {
                    return request.eventLoop.future()
                }

                return request.db.transaction { db in
                    return BuyerTrackedItem.query(on: db)
                        .filter(\.$trackedItem.$id ~~ trackedItemIDs)
                        .delete()
                        .flatMap {
                            return trackedItems.delete(on: db)
                        }
                }
            }.transform(to: .ok)
    }

    private func deleteHandler(request: Request) throws -> EventLoopFuture<HTTPResponseStatus> {
        guard let masterSellerID = request.application.masterSellerID else {
            throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
        }

        guard let trackedItemID: TrackedItem.IDValue = request.parameters.get(TrackedItem.parameter) else {
            throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
        }

        return request.trackedItems
            .find(filter: .init(ids: [trackedItemID], sellerID: masterSellerID, limit: 1))
            .first()
            .flatMap { (trackedItem: TrackedItem?) -> EventLoopFuture<Void> in
                if let trackedItem = trackedItem {
                    return trackedItem
                        .$buyerTrackedItems
                        .get(on: request.db)
                        .flatMap { buyerTrackedItems in
                            return request.db.transaction { db in
                                return buyerTrackedItems.delete(on: db)
                                    .flatMap {
                                        return trackedItem.delete(on: db)
                                    }
                            }
                        }
                } else {
                    return request.eventLoop.future()
                }
            }.transform(to: .ok)
    }

    private func createMultipleHandler(request: Request) throws -> EventLoopFuture<[TrackedItem]> {
        guard let masterSellerID = request.application.masterSellerID else {
            throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
        }

        try CreateMultipleTrackedItemInput.validate(content: request)
        let input = try request.content.decode(CreateMultipleTrackedItemInput.self)

        let mapFn = { trackingNumber throws -> EventLoopFuture<(TrackedItem, Bool)> in
            return try self.createOrUpdate(sellerID: masterSellerID, trackingNumber, on: request)
        }

        return try input.trackingNumbers.chunked(
            10,
            mapFn: mapFn,
            on: request.eventLoop
        ).tryFlatMap { results in
            let allItems = results.map(\.0)
            let stateChangedItems = results.filter {
                return $0.1
            }.map(\.0)
            
            guard !stateChangedItems.isEmpty else {
                return request.eventLoop.future(allItems)
            }

            return try request.emails.sendTrackedItemsUpdateEmail(for: stateChangedItems)
                .transform(to: allItems)
        }
    }

    private func createHandler(request: Request) throws -> EventLoopFuture<TrackedItem> {
        guard let masterSellerID = request.application.masterSellerID else {
            throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
        }

        try CreateTrackedItemInput.validate(content: request)
        let input = try request.content.decode(CreateTrackedItemInput.self)
        return try self.createOrUpdate(sellerID: masterSellerID, input.trackingNumber, sellerNote: input.sellerNote, on: request)
            .tryFlatMap { trackedItem, stateChanged in
                if stateChanged {
                    return try request.emails.sendTrackedItemUpdateEmail(for: trackedItem)
                        .transform(to: trackedItem)
                } else {
                    return request.eventLoop.future(trackedItem)
                }
            }
    }

    private func createOrUpdate(sellerID: Seller.IDValue, _ trackingNumber: String, sellerNote: String? = nil, on request: Request) throws -> EventLoopFuture<(TrackedItem, Bool)> {
        return request.trackedItems
            .find(
                filter: .init(
                    sellerID: sellerID,
                    trackingNumbers: [trackingNumber],
                    limit: 1
                )
            ).first()
            .flatMap { existingTrackedItem in
                if let trackedItem = existingTrackedItem {
                    let trackedItemStateChanged = trackedItem.state != .receivedAtWarehouse
                    trackedItem.trackingNumber = trackingNumber
                    trackedItem.state = .receivedAtWarehouse
                    trackedItem.sellerNote = sellerNote ?? ""
                    return request.trackedItems.save(trackedItem)
                        .transform(to: (trackedItem, trackedItemStateChanged))
                } else {
                    let trackedItem = TrackedItem(sellerID: sellerID, trackingNumber: trackingNumber, state: .receivedAtWarehouse, sellerNote: sellerNote ?? "")
                    return request.trackedItems.save(trackedItem)
                        .transform(to: (trackedItem, false))
                }
            }
    }

    private func getPaginatedHandler(request: Request) throws -> EventLoopFuture<GetPaginatedOutput> {
        let pageRequest = try request.query.decode(PageRequest.self)

        struct QueryBody: Content {
            let searchString: String?
        }

        guard let masterSellerID = request.application.masterSellerID else {
            throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
        }

        let input = try request.query.decode(QueryBody.self)
        let searchStrings = [input.searchString].compactMap { $0 }
        
        return request.trackedItems.find(filter: .init(sellerID: masterSellerID, searchStrings: searchStrings))
            .map { items in
                let indexedItems: [String: [TrackedItem]] = Dictionary.init(grouping: items) { item in
                    let createdAt = item.createdAt ?? Date()
                    return createdAt.toISODate()
                }
                let keys = indexedItems.keys.sorted(by: >)
                var pagedKeys = Array(keys)

                if pageRequest.per != -1 {
                    let page = pageRequest.page
                    let fromIndex = (page - 1) * pageRequest.per
                    let toIndex = (page) * pageRequest.per
                    if pagedKeys.count <= fromIndex {
                        pagedKeys = []
                    } else if pagedKeys.count <= toIndex {
                        pagedKeys = Array(pagedKeys[fromIndex...])
                    } else {
                        pagedKeys = Array(pagedKeys[fromIndex..<toIndex])
                    }

                    let pagedItems = pagedKeys.reduce(into: [String: [TrackedItem]]()) { carry, next in
                        carry[next] = indexedItems[next] ?? []
                    }

                    return GetPaginatedOutput(searchString: input.searchString, items: pagedItems, metadata: .init(page: page, per: pageRequest.per, total: keys.count))
                } else {
                    return GetPaginatedOutput(searchString: input.searchString, items: indexedItems, metadata: .init(page: 1, per: -1, total: keys.count))
                }
            }
    }

    private func getByPeriodHandler(request: Request) throws -> EventLoopFuture<GetTrackedItemByPeriodOutput> {
        guard let masterSellerID = request.application.masterSellerID else {
            throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
        }
        struct QueryBody: Decodable {
            @OptionalISO8601Date var fromDate: Date?
            @OptionalISO8601Date var toDate: Date?
            var searchString: String?
            
            enum CodingKeys: String, CodingKey {
                case fromDate, toDate, searchString
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self._fromDate = try container.decodeIfPresent(OptionalISO8601Date.self, forKey: .fromDate) ?? .init(date: nil)
                self._toDate = try container.decodeIfPresent(OptionalISO8601Date.self, forKey: .toDate) ?? .init(date: nil)
                self.searchString = try container.decodeIfPresent(String.self, forKey: .searchString)
            }
        }

        let input = try request.query.decode(QueryBody.self)

        var dateRange: DateInterval? = nil
        if let fromDate = input.fromDate, let toDate = input.toDate {
            dateRange = .init(start: fromDate, end: toDate)
        }
        if dateRange == nil && (input.searchString == nil || input.searchString?.isEmpty == true) {
            let today = Calendar.current.startOfDay(for: Date())
            let lastThreeDays = today.addingTimeInterval(-60*60*24*3)

            dateRange = .init(start: lastThreeDays, end: today)
        }

        return request.trackedItems.find(
            filter: .init(
                sellerID: masterSellerID,
                searchStrings: [input.searchString].compactMap { $0 },
                dateRange: dateRange
            )
        ).map { trackedItems in
            return .init(fromDate: input.fromDate, toDate: input.toDate, items: trackedItems)
        }
    }
}

extension Array {
    func chunked<T>(_ batchSize: Int, mapFn: @escaping (Element) throws -> EventLoopFuture<T>, on eventLoop: EventLoop) throws -> EventLoopFuture<[T]> {
        let batch = self.prefix(batchSize)

        guard !batch.isEmpty else {
            return eventLoop.future([])
        }

        return try batch.map(mapFn)
            .flatten(on: eventLoop)
            .tryFlatMap { results -> EventLoopFuture<[T]> in
                if batch.count < batchSize {
                    return eventLoop.future(results)
                } else {
                    let nextBatch = Array(self.suffix(from: batchSize))
                    return try nextBatch.chunked(batchSize, mapFn: mapFn, on: eventLoop)
                        .map { nextBatchResults in
                            var returns = results
                            returns.append(contentsOf: nextBatchResults)
                            return returns
                        }
                }
            }
    }
}
