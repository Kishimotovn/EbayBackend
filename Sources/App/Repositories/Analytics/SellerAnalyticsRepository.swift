//
//  File.swift
//  
//
//  Created by Phan Tran on 30/05/2020.
//

import Foundation
import Vapor
import FluentPostgresDriver
import Fluent

protocol SellerAnalyticsRepository {
    func buyerAnalytics(sellerID: Seller.IDValue) -> EventLoopFuture<[BuyerAnalyticsOutput]>
}

struct DatabaseSellerAnalyticsRepository: SellerAnalyticsRepository {
    let db: Database

    func buyerAnalytics(sellerID: Seller.IDValue) -> EventLoopFuture<[BuyerAnalyticsOutput]> {
        return (self.db as! PostgresDatabase).query(
            """
            select
                b.id,
                row_number() OVER (order by b.created_at) as "index",
                b.username,
                b.email,
                b.created_at as "joinDate",
                count(distinct o.id) as "orderCount",
                (sum(i.original_price * oi.quantity * op.rate) :: bigint) as "totalRevenue",
                avg(op.rate) as "avgRate"
            from buyers b
            left join orders o on o.buyer_id = b.id
            left join sellers s on o.seller_id = s.id
            left join order_item oi on o.id = oi.order_id
            left join order_options op on op.id = o.order_option_id
            left join item i on i.id = oi.item_id
            where s.id = $1
            group by b.id;
            """,
            [PostgresData(uuid: sellerID)]
        ).flatMapEachCompactThrowing { (row) -> BuyerAnalyticsOutput in
            return try row.sql().decode(model: BuyerAnalyticsOutput.self)
        }
    }
}

struct SellerAnalyticsRepositoryFactory {
    var make: ((Request) -> SellerAnalyticsRepository)?
    
    mutating func use(_ make: @escaping ((Request) -> SellerAnalyticsRepository)) {
        self.make = make
    }
}

extension Application {
    private struct SellerAnalyticsRepositoryKey: StorageKey {
        typealias Value = SellerAnalyticsRepositoryFactory
    }
    
    var sellerAnalytics: SellerAnalyticsRepositoryFactory {
        get {
            self.storage[SellerAnalyticsRepositoryKey.self] ?? .init()
        }
        set {
            self.storage[SellerAnalyticsRepositoryKey.self] = newValue
        }
    }
}

extension Request {
    var sellerAnalytics: SellerAnalyticsRepository {
        self.application.sellerAnalytics.make!(self)
    }
}
