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
                                            let isInStock = item.lastKnownAvailability == true
                                            let appFrontendURL = context.application.appFrontendURL ?? ""

                                            let emailContent: String
                                            let emailTitle: String
                                            if isInStock {
                                                emailTitle = "Item đã có hàng!"
                                                emailContent = """
                                                  <p>Item <a href="\(item.itemURL)">\(item.name ?? item.itemURL)</a> đã có hàng. Truy cập <a href="\(appFrontendURL)">link</a> để đặt hàng ngay.</p>
                                                """
                                            } else {
                                                emailTitle = "Item đã hết hàng!"
                                                emailContent = """
                                                  <p>Item <a href="\(item.itemURL)">\(item.name ?? item.itemURL)</a> đã hết hàng :(.</p>
                                                """
                                            }
                                            let emailPayload = EmailJobPayload(destination: "annavux@gmail.com", title: emailTitle, content: emailContent)
                                            
                                            return context
                                                .application
                                                .queues
                                                .queue
                                                .dispatch(EmailJob.self,
                                                          emailPayload)
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
