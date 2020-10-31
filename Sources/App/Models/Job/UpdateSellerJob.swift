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

struct UpdateSellerJob: ScheduledJob {
    func run(context: QueueContext) -> EventLoopFuture<Void> {
        return SellerSellerSubscription.query(on: context.application.db)
            .all()
            .tryFlatMap { subscriptions in
                let now = Date()
                let calendar = Calendar.current
                let minutes = calendar.component(.minute, from: now)

                let validSubscriptions: [SellerSellerSubscription] = subscriptions.filter { subscription in
                    return (minutes % (subscription.scanInterval ?? context.application.scanInterval)) == 0
                }

                guard !validSubscriptions.isEmpty else {
                    return context.eventLoop.future()
                }

                let clientEbayRepository = ClientEbayAPIRepository(
                    application: context.application,
                    client: context.application.client,
                    ebayAppID: context.application.ebayAppID ?? "",
                    ebayAppSecret: context.application.ebayAppSecret ?? "")

                let allPromises: [EventLoopFuture<Void>] = validSubscriptions
                    .map { subscription in
                        return clientEbayRepository
                            .searchItems(seller: subscription.sellerName, keyword: subscription.keyword)
                            .flatMap { response -> EventLoopFuture<(EbayItemSearchResponse, Bool, [Change<EbayItemSummaryResponse>])> in
                                let oldItems = subscription.response.itemSummaries ?? []
                                let newItems = response.itemSummaries ?? []
                                let changes = diff(old: oldItems, new: newItems)
                                let changesCount = changes.count
                                let reorderCount = changes.compactMap { $0.move }.count
                                let changesThatAreNotPriceCount = changes.compactMap { $0.replace }.filter {
                                    return $0.oldItem.price == $0.newItem.price && $0.oldItem.marketingPrice == $0.newItem.marketingPrice
                                }.count
                                let shouldNotify = !changes.isEmpty && changesCount != (reorderCount + changesThatAreNotPriceCount)
                                subscription.response = response
                                return subscription
                                    .save(on: context.application.db)
                                    .transform(to: (response, shouldNotify, changes))
                            }
                            .tryFlatMap { (response, shouldNotify, changes) in
                                if shouldNotify {
                                    let emailTitle: String = "🚀 Seller thay đổi!"
                                    let emailContent: String
                                    let changesThatArePriceChanges = changes.compactMap { $0.replace }.filter {
                                        return $0.oldItem.price != $0.newItem.price || $0.oldItem.marketingPrice != $0.newItem.marketingPrice
                                    }
                                    let changeContent: String = """
                                    - Thêm [\(changes.compactMap{ $0.insert }.count)]:<br/> (\(changes.compactMap{ $0.insert }.map {
                                    """
                                    <a href="\($0.item.itemWebUrl)">\($0.item.title)</a> - \($0.item.price.value ?? "N/A")
                                    """ }.joined(separator: "<br/>")))<br/><br/>
                                    - Thay đổi giá [\(changesThatArePriceChanges.count)]:<br/> \(changesThatArePriceChanges.map { """
                                                                        <a href="\($0.newItem.itemWebUrl)">\($0.oldItem.title) -> \($0.newItem.title)</a>, \($0.oldItem.price.value ?? "N/A") -> \($0.newItem.price.value ?? "N/A")
                                    """ }.joined(separator: "<br/>"))<br/><br/>
                                    - Hết [\(changes.compactMap{ $0.delete }.count)]:<br/> \(changes.compactMap{ $0.delete }.map { """
                                                                        <a href="\($0.item.itemWebUrl)">\($0.item.title)</a> - \($0.item.price.value ?? "N/A")
                                    """ }.joined(separator: "<br/>"))
                                    <br/><br/><br/>
                                    List:<br/>
                                    \((response.itemSummaries ?? []).sorted { lhs, rhs in
                                        return lhs.title < rhs.title
                                    }.map { """
                                    <a href="\($0.itemWebUrl)">\($0.title)</a> - \($0.price.value ?? "N/A")
                                    """ }.joined(separator: "<br/>"))
                                    """
                                    if let name = subscription.customName {
                                        emailContent = """
                                            [\(name)]<br/><br/>
                                            \(changeContent)
                                        """
                                    } else {
                                        emailContent = """
                                            [\(subscription.sellerName)][\(subscription.keyword)]<br/><br/>
                                            \(changeContent)
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
                    }

                return self.runByChunk(futures: allPromises, eventLoop: context.eventLoop)
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
