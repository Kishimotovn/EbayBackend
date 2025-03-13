//
//  File.swift
//  
//
//  Created by Phan Anh Tran on 25/01/2022.
//

import Foundation
import Vapor
import Fluent

struct BuyerTrackedItemFilter {
    var ids: [BuyerTrackedItem.IDValue]? = nil
    var buyerID: Buyer.IDValue? = nil
    var trackingNumbers: [String]? = nil
    var limit: Int? = nil
}

protocol BuyerTrackedItemRepository {
    func find(filter: BuyerTrackedItemFilter) -> EventLoopFuture<[BuyerTrackedItem]>
    func paginated(filter: BuyerTrackedItemFilter, pageRequest: PageRequest) -> EventLoopFuture<Page<BuyerTrackedItem>>
}

struct DatabaseBuyerTrackedItemRepository: BuyerTrackedItemRepository, DatabaseRepository {
    let db: Database

    func find(filter: BuyerTrackedItemFilter) -> EventLoopFuture<[BuyerTrackedItem]> {
        let query = BuyerTrackedItem.query(on: db)
        self.apply(filter, to: query)
        query.with(\.$buyer)
        _ = query
            .sort(\.$createdAt, .descending)
        return query.all()
    }

    func paginated(filter: BuyerTrackedItemFilter, pageRequest: PageRequest) -> EventLoopFuture<Page<BuyerTrackedItem>> {
        let query = BuyerTrackedItem.query(on: db)
        self.apply(filter, to: query)
        _ = query
            .sort(\.$createdAt, .descending)
        return query.paginate(pageRequest)
    }

    private func apply(_ filter: BuyerTrackedItemFilter, to query: QueryBuilder<BuyerTrackedItem>) {
        if let ids = filter.ids {
            query.filter(\.$id ~~ ids)
        }
        if let buyerID = filter.buyerID {
            query.filter(\.$buyer.$id == buyerID)
        }
        if let trackingNumbers = filter.trackingNumbers, !trackingNumbers.isEmpty {
            query.group(.or) { builder in
                builder.filter(\.$trackingNumber ~~ trackingNumbers)
                trackingNumbers.forEach { number in
                    builder.filter(.sql(raw: "'\(number)'::text ILIKE CONCAT('%',\(BuyerTrackedItem.schema).tracking_number)"))
                }
                let regexSuffixGroup = trackingNumbers.joined(separator: "|")
                let fullRegex = "^.*(\(regexSuffixGroup))$"
                builder.filter(.sql(raw: "\(BuyerTrackedItem.schema).tracking_number"), .custom("~*"), .bind(fullRegex))
            }
        }
        if let limit = filter.limit {
            query.limit(limit)
        }
    }
}

final class TrackedItemAlias: ModelAlias {
    static let name = "alias_tracked_items"
    let model = TrackedItem()
}

struct BuyerTrackedItemRepositoryFactory: @unchecked Sendable  {
    var make: ((Request) -> (BuyerTrackedItemRepository & DatabaseRepository))?

    mutating func use(_ make: @escaping ((Request) -> (BuyerTrackedItemRepository & DatabaseRepository))) {
        self.make = make
    }
}

extension Application {
    private struct BuyerTrackedItemRepositoryKey: StorageKey {
        typealias Value = BuyerTrackedItemRepositoryFactory
    }

    var buyerTrackedItems: BuyerTrackedItemRepositoryFactory {
        get {
            self.storage[BuyerTrackedItemRepositoryKey.self] ?? .init()
        }
        set {
            self.storage[BuyerTrackedItemRepositoryKey.self] = newValue
        }
    }
}

extension Request {
    var buyerTrackedItems: BuyerTrackedItemRepository & DatabaseRepository {
        self.application.buyerTrackedItems.make!(self)
    }
}
