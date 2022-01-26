//
//  File.swift
//  
//
//  Created by Phan Anh Tran on 24/01/2022.
//

import Foundation
import Vapor
import Fluent

protocol DatabaseRepository {
    var db: Database { get }
    func save<M: Model>(_ model: M) -> EventLoopFuture<Void>
    func delete<M: Model>(_ model: M) -> EventLoopFuture<Void>
    func delete<M: Model>(modelType: M.Type, id: M.IDValue) -> EventLoopFuture<Void>
}

extension DatabaseRepository {
    func save<M: Model>(_ model: M) -> EventLoopFuture<Void> {
        return model.save(on: self.db)
    }

    func delete<M: Model>(_ model: M) -> EventLoopFuture<Void> {
        return model.delete(on: self.db)
    }

    func delete<M: Model>(modelType: M.Type, id: M.IDValue) -> EventLoopFuture<Void> {
        return modelType.query(on: self.db)
            .filter(.id, .equal, id)
            .delete()
    }
}
