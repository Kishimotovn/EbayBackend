//
//  File.swift
//  
//
//  Created by Phan Anh Tran on 24/01/2022.
//

import Foundation
import Vapor
import Fluent
import CodableCSV
import SQLKit

struct SellerTrackedItemController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let groupedRoutes = routes.grouped("sellerTrackedItems")

        groupedRoutes.get(use: getPaginatedHandler)
        groupedRoutes.get("byPeriod", use: getByPeriodHandler)
        groupedRoutes.get("search", use: searchForTrackingItemsHandler)
        groupedRoutes.post(use: createHandler)
        groupedRoutes.post("multiple", use: createMultipleHandler)
        groupedRoutes.on(.POST, "uploadByState", ":state", body: .collect(maxSize: "50mb"), use: uploadByStateHandler)
        groupedRoutes.get("uploadJobs", use: getUploadJobsHandler)
        groupedRoutes.delete("revertJob", TrackedItemUploadJob.parameterPath, use: revertUploadJobsHandler)
    }

    struct UploadTrackedItemsByDayOutput: Content {
        var totalCount: Int
        var countByDate: [String: Int]
    }

    private func revertUploadJobsHandler(request: Request) async throws -> TrackedItemUploadJob {
        guard let jobID = request.parameters.get(TrackedItemUploadJob.parameter, as: TrackedItemUploadJob.IDValue.self) else {
            throw AppError.uploadJobNotFound
        }

        guard let job = try await TrackedItemUploadJob.query(on: request.db)
            .filter(\.$id == jobID)
            .first()
        else {
            throw AppError.uploadJobNotFound
        }

        if job.jobState == .pending || job.jobState == .error {
            if job.jobState == .pending {
                try? await request.fileStorages.delete(name: job.fileID, folder: "Ebay1991").get()
            }
            try await job.delete(on: request.db)
            return job
        }

        if job.jobState == .running {
            throw AppError.uploadJobNotFound
        }

        let runningJob = try await TrackedItemUploadJob.query(on: request.db)
            .filter(\.$jobState == .running)
            .first()

        guard runningJob == nil else {
            throw AppError.uploadJobRunning
        }

        guard job.jobState == .finished, let importID = job.importID else {
            throw AppError.uploadJobNotFound
        }

        try await request.db.transaction { db in
            let allTrackedItems = try await TrackedItem.query(on: db)
                .filter(.sql(raw: "'\(importID)'=ANY(import_ids)"))
                .all()

            allTrackedItems.forEach { trackedItem in
                trackedItem.stateTrails = trackedItem.stateTrails.filter {
                    $0.importID != importID
                }
                trackedItem.importIDs.removeAll(where: { $0 == importID })
            }

            let groups = Dictionary(grouping: allTrackedItems) { $0.stateTrails.isEmpty }
            let allUpdatingItems = groups[false] ?? []
            let allDeletingItems = groups[true] ?? []

            if !allUpdatingItems.isEmpty {
                try await allUpdatingItems.asyncForEach { trackedItem in
                    try await trackedItem.save(on: db)
                }
            }
            
            if !allDeletingItems.isEmpty {
                try await allDeletingItems.delete(on: db)
            }
            
            try await job.delete(on: db)
            try await (db as? SQLDatabase)?.raw("""
            REFRESH MATERIALIZED VIEW CONCURRENTLY \(BuyerTrackedItemLinkView.schema);
            """).run()
            try await (db as? SQLDatabase)?.raw("""
            REFRESH MATERIALIZED VIEW CONCURRENTLY \(TrackedItemActiveState.schema);
            """).run()
        }

        return job
    }

    private func getUploadJobsHandler(request: Request) async throws -> Page<TrackedItemUploadJob> {
        guard let masterSellerID = request.application.masterSellerID else {
            throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
        }

        let query = TrackedItemUploadJob.query(on: request.db)
            .filter(\.$seller.$id == masterSellerID)
            .sort(\.$createdAt, .descending)

        return try await query.paginate(for: request)
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

        let foundTrackedItems = try await request.trackedItems
            .find(filter: .init(searchStrings: input.validTrackingNumbers()))
            .get()
        
        let foundTrackingNumbers = foundTrackedItems.map(\.trackingNumber)

        let notFoundItems = input.validTrackingNumbers().filter { trackingNumber in
            !foundTrackingNumbers.contains(where: { $0.hasSuffix(trackingNumber) })
        }.map { trackingNumber in
            return TrackedItem.init(sellerID: masterSellerID, trackingNumber: trackingNumber, stateTrails: [], sellerNote: "", importIDs: [])
        }
        
        var items = notFoundItems
        items.append(contentsOf: foundTrackedItems)
        return items
    }

    private func uploadByStateHandler(request: Request) async throws -> TrackedItemUploadJob {
        guard
            let masterSellerID = request.application.masterSellerID,
            let stateRaw = request.parameters.get("state", as: String.self),
            let state = TrackedItem.State(rawValue: stateRaw)
        else {
            throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
        }

        struct Input: Codable {
            var uploadFile: File
        }
        
        let input = try request.content.decode(Input.self)
        var file = input.uploadFile

        let data = Data(buffer: file.data)
        
        let string = String(buffer: file.data)
        print(string)

        let reader = try CSVReader(input: data) {
            $0.headerStrategy = .none
            $0.presample = false
            $0.escapingStrategy = .doubleQuote
            $0.delimiters.row = "\r\n"
        }

        while let row = try reader.readRow() { }

        let fileName = file.filename.folding(options: .diacriticInsensitive, locale: .current)
        file.filename = fileName
        let fileID = try await request.fileStorages.upload(file: file, to: "Ebay1991").get()
        print("uploaded file at path", fileID)

        let newJob = TrackedItemUploadJob(
            fileID: fileID,
            jobState: .pending,
            fileName: file.filename,
            state: state,
            sellerID: masterSellerID
        )

        try await newJob.save(on: request.db)
        
        let dispatchPayload = UpdateTrackedItemJobPayload.init()
        try await request.queue.dispatch(
            UpdateTrackedItemsJob.self,
            dispatchPayload)
        
        return newJob
    }

    private func createMultipleHandler(request: Request) async throws -> [TrackedItem] {
        guard let masterSellerID = request.application.masterSellerID else {
            throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
        }

        try CreateMultipleTrackedItemInput.validate(content: request)
        let input = try request.content.decode(CreateMultipleTrackedItemInput.self)
        
        let importID = "manual-\(input.state)-\(Date().toISODateTime())"
        
        let results = try await input.trackingNumbers.asyncMap { trackingNumber in
            return try await self.createOrUpdate(
                sellerID: masterSellerID, trackingNumber,
                sellerNote: input.sellerNote ?? "",
                state: input.state,
                date: Date(),
                on: request,
                importID: importID)
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
        let importID = "manual-\(input.state)-\(Date().toISODateTime())"
        let (trackedItem, stateChanged) = try await self.createOrUpdate(sellerID: masterSellerID, input.trackingNumber, sellerNote: input.sellerNote, state: input.state, date: Date(), on: request, importID: importID)

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
        on request: Request,
        importID: String,
        db: Database? = nil
    ) async throws -> (TrackedItem, Bool) {
        if let existingTrackedItem = try await request.trackedItems.find(
            filter: .init(
                sellerID: sellerID,
                trackingNumbers: [trackingNumber],
                limit: 1
            ),
            on: db
        ).first(
        ).get() {
            let trackedItemStateChanged = !existingTrackedItem.stateTrails.contains {
                $0.state == state && $0.updatedAt == date
            }
            existingTrackedItem.trackingNumber = trackingNumber

            if trackedItemStateChanged {
                let newTrail = TrackedItem.StateTrail.init(
                    state: state,
                    updatedAt: date,
                    importID: importID
                )
                existingTrackedItem.stateTrails.append(newTrail)
                existingTrackedItem.importIDs.append(importID)
            }

            if let sellerNote = sellerNote {
                existingTrackedItem.sellerNote = sellerNote
            }
            try await request.trackedItems.save(existingTrackedItem, on: db).get()
            return (existingTrackedItem, trackedItemStateChanged)
        } else {
            let newTrail = TrackedItem.StateTrail(state: state, updatedAt: date, importID: importID)
            let trackedItem = TrackedItem(
                sellerID: sellerID,
                trackingNumber: trackingNumber,
                stateTrails: [newTrail],
                sellerNote: sellerNote ?? "",
                importIDs: [importID]
            )

            try await request.trackedItems.save(trackedItem, on: db).get()
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
