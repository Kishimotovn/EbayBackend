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
        groupedRoutes.post(use: createHandler)
        groupedRoutes.post("multiple", use: createMultipleHandler)
        groupedRoutes.delete(TrackedItem.parameterPath, use: deleteHandler)
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
                    return request.trackedItems.delete(trackedItem)
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

        let mapFn = { trackingNumber throws -> EventLoopFuture<TrackedItem> in
            return try self.createOrUpdate(sellerID: masterSellerID, trackingNumber, on: request)
        }

        return try input.trackingNumbers.chunked(
            10,
            mapFn: mapFn,
            on: request.eventLoop)
    }

    private func createHandler(request: Request) throws -> EventLoopFuture<TrackedItem> {
        guard let masterSellerID = request.application.masterSellerID else {
            throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
        }

        try CreateTrackedItemInput.validate(content: request)
        let input = try request.content.decode(CreateTrackedItemInput.self)
        return try self.createOrUpdate(sellerID: masterSellerID, input.trackingNumber, sellerNote: input.sellerNote, on: request)
    }

    private func createOrUpdate(sellerID: Seller.IDValue, _ trackingNumber: String, sellerNote: String? = nil, on request: Request) throws -> EventLoopFuture<TrackedItem> {
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
                    trackedItem.state = .receivedAtWarehouse
                    trackedItem.sellerNote = sellerNote ?? ""
                    return request.trackedItems.save(trackedItem)
                        .transform(to: trackedItem)
                } else {
                    let trackedItem = TrackedItem(sellerID: sellerID, trackingNumber: trackingNumber, state: .receivedAtWarehouse, sellerNote: sellerNote ?? "")
                    return request.trackedItems.save(trackedItem)
                        .transform(to: trackedItem)
                }
            }
    }

    private func getPaginatedHandler(request: Request) throws -> EventLoopFuture<Page<TrackedItem>> {
        let pageRequest = try request.query.decode(PageRequest.self)
        guard let masterSellerID = request.application.masterSellerID else {
            throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
        }

        return request.trackedItems.paginated(filter: .init(sellerID: masterSellerID), pageRequest: pageRequest)
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
