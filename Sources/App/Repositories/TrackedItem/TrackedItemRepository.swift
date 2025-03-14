//
//  File.swift
//  
//
//  Created by Phan Anh Tran on 24/01/2022.
//

import Foundation
import Vapor
import Fluent
import FluentKit
import SQLKit

struct TrackedItemFilter {
    var ids: [TrackedItem.IDValue]? = nil
    var sellerID: Seller.IDValue?? = nil
    var trackingNumbers: [String]? = nil
    var searchStrings: [String]? = nil
    var dateRange: DateInterval? = nil
    var limit: Int? = nil
    var date: Date? = nil
}

protocol TrackedItemRepository {
    func find(filter: TrackedItemFilter, on db: Database?) -> EventLoopFuture<[TrackedItem]>
    func paginated(filter: TrackedItemFilter, pageRequest: PageRequest) -> EventLoopFuture<Page<TrackedItem>>
}

extension TrackedItemRepository {
    func find(filter: TrackedItemFilter, on db: Database?) async throws -> [TrackedItem] {
        try await self.find(filter: filter, on: db).get()
    }

    func find(filter: TrackedItemFilter) -> EventLoopFuture<[TrackedItem]> {
        return self.find(filter: filter, on: nil)
    }
}

struct DatabaseTrackedItemRepository: TrackedItemRepository, DatabaseRepository {
    let db: Database

    func find(filter: TrackedItemFilter, on db: Database?) -> EventLoopFuture<[TrackedItem]> {
        let query = TrackedItem.query(on: db ?? self.db)
        self.apply(filter, to: query)
        _ = query.sort(\.$createdAt, .descending)
        return query.all()
    }

    func paginated(filter: TrackedItemFilter, pageRequest: PageRequest) -> EventLoopFuture<Page<TrackedItem>> {
        let query = TrackedItem.query(on: db)
        self.apply(filter, to: query)
        _ = query.sort(\.$createdAt, .descending)
        return query.paginate(pageRequest)
    }

    private func apply(_ filter: TrackedItemFilter, to query: QueryBuilder<TrackedItem>) {
        if let ids = filter.ids, !ids.isEmpty {
            query.filter(\.$id ~~ ids)
        }
        if let sellerID = filter.sellerID {
            query.filter(\.$seller.$id == sellerID)
        }
        if let trackingNumbers = filter.trackingNumbers, !trackingNumbers.isEmpty {
            query.group(.or) { builder in
                builder.filter(\.$trackingNumber ~~ trackingNumbers)
                trackingNumbers.forEach { number in
                    builder.filter(.sql(raw: "'\(number)'::text ILIKE CONCAT('%',\(TrackedItem.schema).tracking_number)"))
                    if number.count >= 12 {
                        builder.filter(.sql(raw: "\(TrackedItem.schema).tracking_number ILIKE '%\(number)'"))
                    }
                }
            }
        }
        if let searchStrings = filter.searchStrings, !searchStrings.isEmpty {
            let regexSuffixGroup = searchStrings.joined(separator: "|")
            let fullRegex = "^.*(\(regexSuffixGroup))$"
            query.group(.or) { builder in
                builder.filter(.sql(raw: "\(TrackedItem.schema).tracking_number"), .custom("~*"), .bind(fullRegex))
                builder.group(.and) { andBuilder in
                    let fullRegex2 = "^.*(\(regexSuffixGroup))\\d{4}$"
                    andBuilder.filter(.sql(raw: "char_length(\(TrackedItem.schema).tracking_number)"), .equal, .bind(32))
                    andBuilder.filter(.sql(raw: "\(TrackedItem.schema).tracking_number"), .custom("~*"), .bind(fullRegex2))
                }
            }
        }
        if let dateRange = filter.dateRange {
            query.filter(.sql(raw: "\(TrackedItem.schema).created_at::DATE"), .greaterThanOrEqual, .bind(dateRange.start))
            query.filter(.sql(raw: "\(TrackedItem.schema).created_at::DATE"), .lessThanOrEqual, .bind(dateRange.end))
        }
        if let limit = filter.limit {
            query.limit(limit)
        }
        if let date = filter.date {
            query.filter(.sql(raw: "\(TrackedItem.schema).created_at::DATE"), .equal, .bind(date))
        }
    }
}

struct TrackedItemRepositoryFactory: @unchecked Sendable  {
    var make: ((Request) -> (TrackedItemRepository & DatabaseRepository))?

    mutating func use(_ make: @escaping ((Request) -> (TrackedItemRepository & DatabaseRepository))) {
        self.make = make
    }
}

extension Application {
    private struct TrackedItemRepositoryKey: StorageKey {
        typealias Value = TrackedItemRepositoryFactory
    }

    var trackedItems: TrackedItemRepositoryFactory {
        get {
            self.storage[TrackedItemRepositoryKey.self] ?? .init()
        }
        set {
            self.storage[TrackedItemRepositoryKey.self] = newValue
        }
    }
}

extension Request {
    var trackedItems: TrackedItemRepository & DatabaseRepository {
        self.application.trackedItems.make!(self)
    }
}
