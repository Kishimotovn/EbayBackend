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
import SendGrid

struct UpdateQuantityJob: ScheduledJob {
    func run(context: QueueContext) -> EventLoopFuture<Void> {
        return Item.query(on: context.application.db)
            .join(SellerItemSubscription.self, on: \Item.$id == \SellerItemSubscription.$item.$id, method: .inner)
            .all()
            .flatMap { items -> EventLoopFuture<Void> in
                if items.isEmpty {
                    return context.eventLoop.future()
                } else {
                    let jobMonitoringRepository = DatabaseJobMonitoringRepository(db: context.application.db)
                    let jobMonitoring = JobMonitoring(jobName: self.name)
                    return jobMonitoringRepository.save(jobMonitoring: jobMonitoring)
                        .flatMap {
                            let clientEbayRepository = ClientEbayAPIRepository(
                                client: context.application.client,
                                ebayAppID: context.application.ebayAppID ?? "",
                                ebayAppSecret: context.application.ebayAppSecret ?? "")
                            let itemRepository = DatabaseItemRepository(db: context.application.db)

                            return items.map { (item: Item) in
                                return clientEbayRepository.getItemDetails(ebayItemID: item.itemID)
                                    .flatMap { (output: EbayAPIItemOutput) -> EventLoopFuture<(Item, Bool)> in
                                        let isOutOfStock = output.quantityLeft == "0"
                                        let changedToAvailable = !isOutOfStock && item.lastKnownAvailability != true
                                        let changedToUnavailable = isOutOfStock && item.lastKnownAvailability != false
                                        let shouldNotify = changedToUnavailable || changedToAvailable
                                        item.lastKnownAvailability = !isOutOfStock
                                        return itemRepository
                                            .save(item: item)
                                        .transform(to: (item, shouldNotify))
                                    }.tryFlatMap { item, shouldNotify in
                                        if shouldNotify {
                                            let emailRepository = SendGridEmailRepositoryRepository(
                                                appFrontendURL: context.application.appFrontendURL ?? "",
                                                client: context.application.sendgrid.client,
                                                eventLoop: context.eventLoop)
                                            return try emailRepository.sendItemAvailableEmail(for: item)
                                        } else {
                                            return context.eventLoop.future()
                                        }
                                }
                            }
                            .flatten(on: context.eventLoop)
                    }.flatMap {
                        jobMonitoring.finishedAt = Date()
                        return jobMonitoringRepository.save(jobMonitoring: jobMonitoring)
                    }
                }
            }
    }
}
