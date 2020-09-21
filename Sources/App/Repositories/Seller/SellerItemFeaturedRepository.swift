//
//  File.swift
//  
//
//  Created by Phan Tran on 18/09/2020.
//

import Foundation
import Vapor
import Fluent

protocol SellerItemFeaturedRepository {
    func find(sellerItemFeaturedID: SellerItemFeatured.IDValue) -> EventLoopFuture<SellerItemFeatured?>
    func delete(sellerItemFeaturedID: SellerItemFeatured.IDValue) -> EventLoopFuture<Void>
    func find(sellerID: Seller.IDValue) -> EventLoopFuture<[SellerItemFeatured]>
}

struct DatabaseSellerItemFeaturedRepository: SellerItemFeaturedRepository {
    let db: Database

    func find(sellerItemFeaturedID: SellerItemFeatured.IDValue) -> EventLoopFuture<SellerItemFeatured?> {
        return SellerItemFeatured.query(on: self.db)
            .filter(\.$id == sellerItemFeaturedID)
            .first()
    }

    func find(sellerID: Seller.IDValue) -> EventLoopFuture<[SellerItemFeatured]> {
        return SellerItemFeatured.query(on: self.db)
            .filter(\.$seller.$id == sellerID)
            .with(\.$item)
            .all()
    }

    func delete(sellerItemFeaturedID: SellerItemFeatured.IDValue) -> EventLoopFuture<Void> {
        return SellerItemFeatured.query(on: self.db)
            .filter(\.$id == sellerItemFeaturedID)
            .delete()
    }
}

struct SellerItemFeaturedRepositoryFactory {
    var make: ((Request) -> SellerItemFeaturedRepository)?
    
    mutating func use(_ make: @escaping ((Request) -> SellerItemFeaturedRepository)) {
        self.make = make
    }
}

extension Application {
    private struct SellerItemFeaturedRepositoryKey: StorageKey {
        typealias Value = SellerItemFeaturedRepositoryFactory
    }
    
    var sellerItemFeatured: SellerItemFeaturedRepositoryFactory {
        get {
            self.storage[SellerItemFeaturedRepositoryKey.self] ?? .init()
        }
        set {
            self.storage[SellerItemFeaturedRepositoryKey.self] = newValue
        }
    }
}

extension Request {
    var sellerItemFeatured: SellerItemFeaturedRepository {
        self.application.sellerItemFeatured.make!(self)
    }
}
