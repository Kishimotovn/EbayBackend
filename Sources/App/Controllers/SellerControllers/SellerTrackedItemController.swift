//
//  File.swift
//  
//
//  Created by Phan Anh Tran on 24/01/2022.
//

import Foundation
import Vapor
import Fluent
import SwiftCSV

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
        groupedRoutes.on(.POST, "uploadByState", ":state", body: .collect(maxSize: "50mb"), use: uploadByStateHandler)
    }

    struct UploadTrackedItemsByDayOutput: Content {
        var totalCount: Int
        var countByDate: [String: Int]
    }

    private func uploadByStateHandler(request: Request) async throws -> UploadTrackedItemsByDayOutput {
        guard
            let masterSellerID = request.application.masterSellerID,
            let buffer = request.body.data,
            let stateRaw = request.parameters.get("state", as: String.self),
            let state = TrackedItem.State(rawValue: stateRaw)
        else {
            throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
        }

        let dataString = String.init(buffer: buffer)
        let csv = try NamedCSV(string: dataString)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yyyy"

        var countByDate: [String: Int] = [:]
        var stateChangedItems = [TrackedItem]()
        
        try await csv.header.asyncForEach { header in
            guard let date = dateFormatter.date(from: header) else {
                return
            }

            let allTrackingNumbers = csv.columns?[header]?.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter {
                $0.count > 8
            }.removingDuplicates() ?? []

            countByDate[header] = allTrackingNumbers.count
            
            try await allTrackingNumbers.asyncForEach { trackingNumber in
                let (trackedItem, stateChanged) = try await self.createOrUpdate(
                    sellerID: masterSellerID,
                    trackingNumber,
                    sellerNote: nil,
                    state: state,
                    date: date,
                    on: request)
                if (stateChanged) {
                    stateChangedItems.append(trackedItem)
                }
            }
        }
        
        if !stateChangedItems.isEmpty {
            try await request.emails.sendTrackedItemsUpdateEmail(for: stateChangedItems).get()
        }

        let totalCount = countByDate.values.reduce(0, +)
        return .init(
            totalCount: totalCount,
            countByDate: countByDate
        )
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

    private func createMultipleHandler(request: Request) async throws -> [TrackedItem] {
        guard let masterSellerID = request.application.masterSellerID else {
            throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
        }

        try CreateMultipleTrackedItemInput.validate(content: request)
        let input = try request.content.decode(CreateMultipleTrackedItemInput.self)
        
        let results = try await input.trackingNumbers.asyncMap { trackingNumber in
            return try await self.createOrUpdate(
                sellerID: masterSellerID, trackingNumber,
                sellerNote: input.sellerNote ?? "",
                state: input.state,
                date: Date(),
                on: request)
        }

        let allItems = results.map(\.0)
        let stateChangedItems = results.filter {
            return $0.1
        }.map(\.0)
        
        if !stateChangedItems.isEmpty {
            try await request.emails.sendTrackedItemsUpdateEmail(for: stateChangedItems).get()
        }

        return allItems
    }

    private func createHandler(request: Request) async throws -> TrackedItem {
        guard let masterSellerID = request.application.masterSellerID else {
            throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
        }

        try CreateTrackedItemInput.validate(content: request)
        let input = try request.content.decode(CreateTrackedItemInput.self)
        let (trackedItem, stateChanged) = try await self.createOrUpdate(sellerID: masterSellerID, input.trackingNumber, sellerNote: input.sellerNote, state: input.state, date: Date(), on: request)

        if stateChanged {
            try await request.emails.sendTrackedItemUpdateEmail(for: trackedItem).get()
        }
        
        return trackedItem
    }

    private func createOrUpdate(
        sellerID: Seller.IDValue,
        _ trackingNumber: String,
        sellerNote: String? = nil,
        state: TrackedItem.State,
        date: Date,
        on request: Request
    ) async throws -> (TrackedItem, Bool) {
        if let existingTrackedItem = try await request.trackedItems.find(
            filter: .init(
                sellerID: sellerID,
                trackingNumbers: [trackingNumber],
                limit: 1
            )
        ).first(
        ).get() {
            let trackedItemStateChanged = !existingTrackedItem.stateTrails.contains {
                $0.state == state && $0.updatedAt == date
            }
            existingTrackedItem.trackingNumber = trackingNumber

            if trackedItemStateChanged {
                let newTrail = TrackedItem.StateTrail.init(state: state, updatedAt: date)
                existingTrackedItem.stateTrails.append(newTrail)
            }

            if let sellerNote = sellerNote {
                existingTrackedItem.sellerNote = sellerNote
            }
            try await request.trackedItems.save(existingTrackedItem).get()
            return (existingTrackedItem, trackedItemStateChanged)
        } else {
            let newTrail = TrackedItem.StateTrail(state: state, updatedAt: date)
            let trackedItem = TrackedItem(
                sellerID: sellerID,
                trackingNumber: trackingNumber,
                stateTrails: [newTrail],
                sellerNote: sellerNote ?? "")

            try await request.trackedItems.save(trackedItem).get()
            return (trackedItem, false)
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
