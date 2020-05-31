//
//  File.swift
//  
//
//  Created by Phan Tran on 28/05/2020.
//

import Foundation
import Vapor
import Fluent

protocol OrderOptionRepository {
    func all() -> EventLoopFuture<[OrderOption]>
    func save(orderOption: OrderOption) -> EventLoopFuture<Void>
}

struct DatabaseOrderOptionRepository: OrderOptionRepository {
    let db: Database

    func save(orderOption: OrderOption) -> EventLoopFuture<Void> {
        return orderOption.save(on: self.db)
    }

    func all() -> EventLoopFuture<[OrderOption]> {
        return OrderOption
            .query(on: self.db)
            .sort(\.$rate, .descending)
            .all()
    }
}

struct OrderOptionRepositoryFactory {
    var make: ((Request) -> OrderOptionRepository)?
    
    mutating func use(_ make: @escaping ((Request) -> OrderOptionRepository)) {
        self.make = make
    }
}

extension Application {
    private struct OrderOptionRepositoryKey: StorageKey {
        typealias Value = OrderOptionRepositoryFactory
    }
    
    var orderOptions: OrderOptionRepositoryFactory {
        get {
            self.storage[OrderOptionRepositoryKey.self] ?? .init()
        }
        set {
            self.storage[OrderOptionRepositoryKey.self] = newValue
        }
    }
}

extension Request {
    var orderOptions: OrderOptionRepository {
        self.application.orderOptions.make!(self)
    }
}
