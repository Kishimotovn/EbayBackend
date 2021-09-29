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
            .field(SellerItemSubscription.self, \.$customName)
            .field(\.$itemID)
            .field(\.$lastKnownAvailability)
            .field(\.$id)
            .field(\.$name)
            .field(\.$itemURL)
            .field(SellerItemSubscription.self, \.$item.$id)
            .field(SellerItemSubscription.self, \.$isEnabled)
            .all()
            .tryFlatMap { items -> EventLoopFuture<Void> in
                let now = Date()
                let calendar = Calendar.current
                let minutes = calendar.component(.minute, from: now)
                let subscriptions = try items.map {
                    try $0.joined(SellerItemSubscription.self)
                }
                let validItems: [Item] = zip(items, subscriptions).filter { (item, subscription) in
                    return subscription.isEnabled && (minutes % (subscription.scanInterval ?? context.application.scanInterval)) == 0
                }.map { (item, subscription) in
                    return item
                }

                context.application.logger.info("Running scan for \(validItems.count) items")
                if validItems.isEmpty {
                    return context
                        .eventLoop
                        .future()
                } else {
                    let jobMonitoringRepository = DatabaseJobMonitoringRepository(db: context.application.db)
                    let jobMonitoring = JobMonitoring(jobName: self.name)
                    return jobMonitoringRepository.save(jobMonitoring: jobMonitoring)
                        .flatMap {
                            let clientEbayRepository = ClientEbayAPIRepository(
                                application: context.application,
                                client: context.application.client,
                                ebayAppID: context.application.ebayAppID ?? "",
                                ebayAppSecret: context.application.ebayAppSecret ?? "")
                            let itemRepository = DatabaseItemRepository(db: context.application.db)
                            let allPromises: [EventLoopFuture<Void>] = validItems.map { (item: Item) in
                                return clientEbayRepository.getItemDetails(ebayItemID: item.itemID)
                                    .flatMap { (output: EbayAPIItemOutput) -> EventLoopFuture<(Item, Bool, String, Int)> in
                                        let isOutOfStock = output.quantityLeft == "0"
                                        let changedToAvailable = !isOutOfStock && item.lastKnownAvailability != true
                                        let changedToUnavailable = isOutOfStock && item.lastKnownAvailability != false
                                        let shouldNotify = changedToUnavailable || changedToAvailable
                                        item.lastKnownAvailability = !isOutOfStock
                                        let price = (output.originalPrice + output.shippingPrice) - (output.furtherDiscountAmount ?? 0)
                                        return itemRepository
                                            .save(item: item)
                                            .transform(to: (item, shouldNotify, output.quantityLeft ?? "N/A", price))
                                    }.tryFlatMap { item, shouldNotify, quantityLeft, price in
                                        if shouldNotify {
                                            let isInStock = item.lastKnownAvailability == true
                                            let appFrontendURL = context.application.appFrontendURL ?? ""

                                            let emailContent: String
                                            let emailTitle: String
                                            let subscription = subscriptions.first(where: { $0.$item.id == item.id })
                                            let priceDouble = Double(price)/100
                                            if isInStock {
                                                emailTitle = "✅ item Available!"
                                                emailContent = """
                                                <p>[\(quantityLeft)][$\(priceDouble)] <a href="\(item.itemURL)">\(subscription?.customName ?? item.name ?? item.itemURL)</a> đã có hàng. Truy cập <a href="\(appFrontendURL)">link</a> để đặt hàng ngay.</p>
                                                """
                                            } else {
                                                emailTitle = "⛔️ item Outstock!"
                                                emailContent = """
                                                  <p>Item <a href="\(item.itemURL)">\(subscription?.customName ?? item.name ?? item.itemURL)</a> đã hết hàng :(.</p>
                                                """
                                            }
                                            
                                            let emailAddress = EmailAddress(email: "minhdung910@gmail.com")
                                            let emailAddress2 = EmailAddress(email: "chonusebay@gmail.com")

                                            let emailConfig = Personalization(
                                                to: [emailAddress, emailAddress2],
                                                subject: emailTitle)

                                            let fromEmail = EmailAddress(
                                                email: "no-reply@1991ebay.com",
                                                name: "1991Ebay")
                                            
                                            let email = SendGridEmail(
                                                personalizations: [emailConfig],
                                                from: fromEmail,
                                                content: [
                                                  ["type": "text/html",
                                                   "value": emailContent]
                                                ])

                                            return try context
                                                .application
                                                .sendgrid
                                                .client
                                                .send(email: email,
                                                      on: context.eventLoop)
                                        } else {
                                            return context.eventLoop.future()
                                        }
                                }
//                                    .flatMapErrorThrowing { error in
//                                    context.application.logger.error("Failed item scan for \(item) with error \(error)")
//                                    return
//                                }
                            }
                            return self.runByChunk(futures: allPromises, eventLoop: context.eventLoop)
                    }.flatMap {
                        if !validItems.isEmpty {                            jobMonitoring.finishedAt = Date()
                            return jobMonitoringRepository.save(jobMonitoring: jobMonitoring)
                        } else {
                            return context.eventLoop.future()
                        }
                    }
                }
            }
    }

    private func runByChunk<T>(futures: [EventLoopFuture<T>], chunk: Int = 5, eventLoop: EventLoop) -> EventLoopFuture<Void> {
        let batch = futures.prefix(chunk)

        return batch.flatten(on: eventLoop).flatMap { _ in
            if batch.count <= chunk {
                return eventLoop.future()
            } else {
                let newBatch = futures.suffix(from: chunk)
                return self.runByChunk(futures: Array(newBatch), chunk: chunk, eventLoop: eventLoop)
            }
        }
    }
}
