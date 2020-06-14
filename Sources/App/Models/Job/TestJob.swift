//
//  File.swift
//  
//
//  Created by Phan Tran on 13/06/2020.
//

import Foundation
import Vapor
import Fluent
import Queues

struct TestJob: ScheduledJob {
    func run(context: QueueContext) -> EventLoopFuture<Void> {
        return Seller.query(on: context.application.db)
            .first()
            .flatMap { (seller: Seller?) -> EventLoopFuture<Void> in
                if let seller = seller {
                    let sellerRepo = DatabaseSellerRepository(db: context.application.db)
                    seller.updatedAt = Date()
                    return sellerRepo.save(seller: seller)
                } else {
                    return context.eventLoop.future()
                }
        }
    }
}
