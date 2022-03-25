//
//  File.swift
//  
//
//  Created by Phan Tran on 25/10/2020.
//

import Foundation
import Vapor
import Fluent
import Queues
import SendGrid
import DeepDiff

struct UpdateSellerBatchCount: StorageKey {
    typealias Value = Int
}

extension Application {
    var updateSellerBatchCount: Int {
        get { self.storage[UpdateSellerBatchCount.self] ?? 2 }
        set { self.storage[UpdateSellerBatchCount.self] = newValue }
    }
}

struct UpdateSellerJob: ScheduledJob {
    func run(context: QueueContext) -> EventLoopFuture<Void> {
        return SellerSellerSubscription.query(on: context.application.db)
            .all()
            .tryFlatMap { subscriptions in
                let now = Date()
                let calendar = Calendar.current
                let minutes = calendar.component(.minute, from: now)

                let validSubscriptions: [SellerSellerSubscription] = subscriptions.filter { subscription in
                    return subscription.isEnabled && (minutes % (subscription.scanInterval ?? context.application.scanInterval)) == 0
                }

                guard !validSubscriptions.isEmpty else {
                    return context.eventLoop.future()
                }

                context.application.logger.info("Running scan for \(validSubscriptions.count) sellers")
                let clientEbayRepository = ClientEbayAPIRepository(
                    application: context.application,
                    client: context.application.client,
                    ebayAppID: context.application.ebayAppID ?? "",
                    ebayAppSecret: context.application.ebayAppSecret ?? "")

                return self.runByChunk(subscriptions: validSubscriptions,
                                       chunk: context.application.updateSellerBatchCount,
                                       clientEbayRepository: clientEbayRepository,
                                       context: context)
            }
    }
    
    private func runByChunk(subscriptions: [SellerSellerSubscription], chunk: Int, clientEbayRepository: ClientEbayAPIRepository, context: QueueContext) -> EventLoopFuture<Void> {
        let batchSubcription = subscriptions.prefix(chunk)
        context.application.logger.info("Running batch with count: \(batchSubcription.count)")

        let batch = batchSubcription.map { subscription in
            return clientEbayRepository
                .searchItems(seller: subscription.sellerName, keyword: subscription.keyword)
                .flatMap { response -> EventLoopFuture<((EbayItemSearchResponse, Bool, [Change<EbayItemSummaryResponse>]))> in
                    let oldItems = subscription.response.itemSummaries ?? []
                    let newItems = response.itemSummaries ?? []
//
//                    let saleCheckFuture = self.getFurtherDiscounts(for: newItems,
//                                                                   using: clientEbayRepository,
//                                                                   on: context.eventLoop)
                    
                    let changes = diff(old: oldItems, new: newItems)
                    let changesCount = changes.count
                    let reorderCount = changes.compactMap { $0.move }.count
                    let changesThatAreNotPriceCount = changes.compactMap { $0.replace }.filter {
                        return $0.oldItem.price == $0.newItem.price && $0.oldItem.marketingPrice == $0.newItem.marketingPrice
                    }.count
                    let shouldNotify = !changes.isEmpty && changesCount != (reorderCount + changesThatAreNotPriceCount)
                    subscription.response = response
                    
                    let insertChangesCount = changes.compactMap{ $0.insert }.count
                    let changesThatArePriceChangesCount = changes.compactMap { $0.replace }.filter {
                        return $0.oldItem.price != $0.newItem.price || $0.oldItem.marketingPrice != $0.newItem.marketingPrice
                    }.count
                    let deleteChangesCount = changes.compactMap{ $0.delete }.count
                    
                    context.application.logger.info("===========================================")
                    context.application.logger.info("Change count for \(subscription.sellerName) - \(subscription.keyword): \(changesCount)")
                    context.application.logger.info("Reorder count for \(subscription.sellerName) - \(subscription.keyword): \(reorderCount)")
                    context.application.logger.info("Changes that are not price count for \(subscription.sellerName) - \(subscription.keyword): \(changesThatAreNotPriceCount)")
                    context.application.logger.info("Should notify for \(subscription.sellerName) - \(subscription.keyword): \(shouldNotify)")
                    context.application.logger.info("Insert count \(subscription.sellerName) - \(subscription.keyword): \(insertChangesCount)")
                    context.application.logger.info("Delete count for \(subscription.sellerName) - \(subscription.keyword): \(deleteChangesCount)")
                    context.application.logger.info("Price change count for \(subscription.sellerName) - \(subscription.keyword): \(changesThatArePriceChangesCount)")
                    context.application.logger.info("===========================================")

                    return subscription
                        .save(on: context.application.db)
                        .transform(to: (response, shouldNotify, changes))
//                        .and(saleCheckFuture)
                }
                .tryFlatMap { response, shouldNotify, changes in
                    context.application.logger.info("1.")
//                    let hasDiscounts = discounts.filter { $0.0 }.isEmpty == false
//                    let titleAppend = hasDiscounts ? "⚠️" : ""
                    if shouldNotify {
                        context.application.logger.info("2.")
                        var emails: [EventLoopFuture<Void>] = []
                        let listOfEmails = context.application.notificationEmails.map { EmailAddress(email: $0) }

                        let fromEmail = EmailAddress(
                            email: "no-reply@1991ebay.com",
                            name: "1991Ebay")
                        let contentPrefix: String
                        if let name = subscription.customName {
                            contentPrefix = """
                                [\(name)]
                            """
                        } else {
                            contentPrefix = """
                                [\(subscription.sellerName)][\(subscription.keyword)]
                            """
                        }
                        
                        let insertChanges = changes.compactMap{ $0.insert }
                        context.application.logger.info("3. \(insertChanges.count)")
                        if (!insertChanges.isEmpty) {
                            let emailTitle: String = "✅ Seller thêm hàng!"
                            let emailContent: String = """
                            \(contentPrefix) - [\(insertChanges.count)]<br/>
                            \(insertChanges.map {
                                """
                                - <a href="\($0.item.safeWebURL)">\($0.item.safeTitle)</a> - \($0.item.price?.value ?? "N/A")
                                """
                            }.joined(separator: "<br/>"))
                            """
                            let emailConfig = Personalization(
                                to: listOfEmails,
                                subject: emailTitle)

                            let email = SendGridEmail(
                                personalizations: [emailConfig],
                                from: fromEmail,
                                content: [
                                  ["type": "text/html",
                                   "value": emailContent]
                                ])
                            try emails.append(context
                                            .application
                                            .sendgrid
                                            .client
                                            .send(email: email,
                                                  on: context.eventLoop))
                        }
                        
                        let changesThatArePriceChanges = changes.compactMap { $0.replace }.filter {
                            return $0.oldItem.price != $0.newItem.price || $0.oldItem.marketingPrice != $0.newItem.marketingPrice
                        }
                        context.application.logger.info("4. \(changesThatArePriceChanges.count)")
                        if (!changesThatArePriceChanges.isEmpty) {
                            let emailTitle: String = "⚠️ Thay đổi giá!"
                            let priceChangesContent = changesThatArePriceChanges.map { change -> (Bool, Replace<EbayItemSummaryResponse>) in
                                let increasing = (Double(change.newItem.price?.value ?? "") ?? 0) - (Double(change.oldItem.price?.value ?? "") ?? 0) > 0
                                return (increasing, change)
                            }.map { increasing, change -> String in
                                """
                                -  \(increasing ? "🔺" : "🔻") <a href="\(change.newItem.safeWebURL)">\(change.oldItem.safeTitle) -> \(change.newItem.safeTitle)</a>, \(change.oldItem.price?.value ?? "N/A") -> \(change.newItem.price?.value ?? "N/A")
                                """
                            }.joined(separator: "<br/>")
                            let emailContent: String = """
                            \(contentPrefix) - [\(changesThatArePriceChanges.count)]<br/>
                            \(priceChangesContent)
                            """
                            let emailConfig = Personalization(
                                to: listOfEmails,
                                subject: emailTitle)

                            let email = SendGridEmail(
                                personalizations: [emailConfig],
                                from: fromEmail,
                                content: [
                                  ["type": "text/html",
                                   "value": emailContent]
                                ])
                            try emails.append(context
                                            .application
                                            .sendgrid
                                            .client
                                            .send(email: email,
                                                  on: context.eventLoop))
                        }
                        
                        let deleteChanges = changes.compactMap{ $0.delete }
                        context.application.logger.info("5. \(deleteChanges.count)")
                        if !deleteChanges.isEmpty {
                            let emailTitle: String = "💥 Seller hết hàng!"
                            let emailContent: String = """
                            \(contentPrefix) - [\(deleteChanges.count)]<br/>
                            \(deleteChanges.map {
                                """
                                - <a href="\($0.item.safeWebURL)">\($0.item.safeTitle)</a> - \($0.item.price?.value ?? "N/A")
                                """ }.joined(separator: "<br/>"))
                            """
                            let emailConfig = Personalization(
                                to: listOfEmails,
                                subject: emailTitle)

                            let email = SendGridEmail(
                                personalizations: [emailConfig],
                                from: fromEmail,
                                content: [
                                  ["type": "text/html",
                                   "value": emailContent]
                                ])
                            try emails.append(
                                context
                                    .application
                                    .sendgrid
                                    .client
                                    .send(email: email,
                                          on: context.eventLoop))
                        }
                        
                        context.application.logger.info("sending \(emails.count) emails to \(context.application.notificationEmails)")
                        return emails
                            .flatten(on: context.eventLoop)
                    } else {
                        return context.eventLoop.future()
                    }
                }
                .flatMapErrorThrowing { error in
                    context.application.logger.error("Failed seller scan for \(subscription.sellerName) - \(subscription.keyword) with error \(error)")
                    return
                }
        }

        return batch.flatten(on: context.eventLoop).flatMap { _ -> EventLoopFuture<Void> in
            if batchSubcription.count < chunk {
                context.application.logger.info("End... no more chunks")
                return context.eventLoop.future()
            } else {
                let newBatch = subscriptions.suffix(from: chunk)
                context.application.logger.info("Continue with batch: \(newBatch.count)")
                return self.runByChunk(subscriptions: Array(newBatch), chunk: chunk, clientEbayRepository: clientEbayRepository, context: context)
            }
        }
    }

    private func hasFurtherDiscount(itemID: String, discounts: [(Bool, String)]) -> Bool {
        if let discount = discounts.first(where: {$0.1 == itemID}) {
            return discount.0
        }
        return false
    }

//    private func getFurtherDiscounts(
//        for items: [EbayItemSummaryResponse],
//        using repo: ClientEbayAPIRepository,
//        on eventLoop: EventLoop) -> EventLoopFuture<[(Bool, String)]> {
//        return items.compactMap { item in
//            guard let itemURL = item.itemWebUrl, let itemID = item.itemId else {
//                return nil
//            }
//            return repo.checkFurtherDiscountFromWebPage(urlString: itemURL)
//                .flatMapErrorThrowing { error in
//                    repo.application.logger.error("Failed to get further discount \(item.safeTitle) - \(itemURL)")
//                    return false
//                }
//                .and(value: itemID)
//        }.flatten(on: eventLoop)
//    }
}
