//
//  File.swift
//  
//
//  Created by Phan Tran on 25/05/2020.
//

import Foundation
import Vapor
import Fluent

protocol ItemRepository {
    func find(itemID: String) -> EventLoopFuture<Item?>
    func save(item: Item) -> EventLoopFuture<Void>
}

struct DatabaseItemRepository: ItemRepository {
    let db: Database

    func save(item: Item) -> EventLoopFuture<Void> {
        return item.save(on: self.db)
    }

    func find(itemID: String) -> EventLoopFuture<Item?> {
        return Item.query(on: self.db)
            .filter(\.$itemID == itemID)
            .first()
    }
}

struct ItemRepositoryFactory: @unchecked Sendable {
    var make: ((Request) -> ItemRepository)?

    mutating func use(_ make: @escaping ((Request) -> ItemRepository)) {
        self.make = make
    }
}

extension Application {
    private struct ItemRepositoryKey: StorageKey {
        typealias Value = ItemRepositoryFactory
    }

    var items: ItemRepositoryFactory {
        get {
            self.storage[ItemRepositoryKey.self] ?? .init()
        }
        set {
            self.storage[ItemRepositoryKey.self] = newValue
        }
    }
}

extension Request {
    var items: ItemRepository {
        self.application.items.make!(self)
    }
}

