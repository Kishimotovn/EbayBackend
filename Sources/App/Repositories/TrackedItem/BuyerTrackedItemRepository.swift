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
    var trackedItemIDs: [TrackedItem.IDValue]? = nil
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
        query.with(\.$trackedItem)
        query.with(\.$buyer)
        _ = query
            .join(TrackedItemAlias.self, on: \TrackedItemAlias.$id == \BuyerTrackedItem.$trackedItem.$id)
            .sort(\.$createdAt, .descending)
            .sort(TrackedItemAlias.self, \.$updatedAt, .ascending)
        return query.all()
    }

    func paginated(filter: BuyerTrackedItemFilter, pageRequest: PageRequest) -> EventLoopFuture<Page<BuyerTrackedItem>> {
        let query = BuyerTrackedItem.query(on: db)
        self.apply(filter, to: query)
        query.with(\.$trackedItem)
        _ = query
            .join(TrackedItemAlias.self, on: \TrackedItemAlias.$id == \BuyerTrackedItem.$trackedItem.$id)
            .sort(\.$createdAt, .descending)
            .sort(TrackedItemAlias.self, \.$updatedAt, .ascending)
        return query.paginate(pageRequest)
    }

    private func apply(_ filter: BuyerTrackedItemFilter, to query: QueryBuilder<BuyerTrackedItem>) {
        if let ids = filter.ids {
            query.filter(\.$id ~~ ids)
        }
        if let buyerID = filter.buyerID {
            query.filter(\.$buyer.$id == buyerID)
        }
        if let trackedItemIDs = filter.trackedItemIDs, !trackedItemIDs.isEmpty {
            query.filter(\.$trackedItem.$id ~~ trackedItemIDs)
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

struct BuyerTrackedItemRepositoryFactory {
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
