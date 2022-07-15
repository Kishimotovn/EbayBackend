import Foundation
import Vapor
import Fluent
import Queues
import SendGrid
import SwiftSoup
import DeepDiff

struct Product: Content {
    let type: String?
    let image: String?
    let url: String?
    let name: String?

    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case image, url, name
    }
}

struct IpadScanInterval: StorageKey {
    typealias Value = Int
}

extension Application {
    var ipadScanInterval: Int {
        get { self.storage[IpadScanInterval.self] ?? 5 }
        set { self.storage[IpadScanInterval.self] = newValue }
    }
}

struct CheckIpadJob: ScheduledJob {
    struct Product: Content, Equatable, DiffAware {
        let type: String?
        let image: String?
        let url: String?
        let name: String?

        var diffId: String {
            return self.url ?? UUID().uuidString
        }

        var safeWebURL: String {
            return self.url ?? ""
        }

        var safeTitle: String {
            return self.name ?? "N/A"
        }

        static func compareContent(_ a: CheckIpadJob.Product, _ b: CheckIpadJob.Product) -> Bool {
            return a == b
        }

        enum CodingKeys: String, CodingKey {
            case type = "@type"
            case image, url, name
        }

        public static func == (lhs: Product, rhs: Product) -> Bool {
            return lhs.type == rhs.type
                && lhs.image == rhs.image
                && lhs.url == rhs.url
                && lhs.name == rhs.name
        }
    }

    func run(context: QueueContext) -> EventLoopFuture<Void> {
        let interval = context.application.ipadScanInterval
        let now = Date()
        let calendar = Calendar.current
        guard
            let minute = calendar.dateComponents([.minute], from: now).minute,
            minute.isMultiple(of: interval)
        else {
            return context.eventLoop.future()
        }

        let client = context.application.client
        let uri = URI(string: "https://www.apple.com/shop/refurbished/ipad")

        return client.get(uri)
            .flatMapThrowing { response -> [Product] in
                let body = response.body!
                let html = String(buffer: body)
                let doc: Document = try SwiftSoup.parse(html)
                let allScripts = try doc.getElementsByAttributeValue("type", "application/ld+json")
                let jsonDecoder = JSONDecoder()
                let products: [Product] = allScripts.map { element -> String in
                    return element.data()
                }.compactMap { dataString in
                    if
                        let data = dataString.data(using: .utf8),
                        let decodedProduct = try? jsonDecoder.decode(Product.self, from: data),
                        decodedProduct.type == "Product"
                    {
                        return decodedProduct
                    }
                    return nil
                }
                return products
            }.tryFlatMap { products in
                return context.application.redis.get("ipad_products", asJSON: [Product].self)
                    .unwrap(orElse: { [Product]() })
                    .and(value: products.sorted { lhs, rhs in
                        return (lhs.name ?? "") < (rhs.name ?? "")
                    })
            }.tryFlatMap { oldItems, newItems in
                if oldItems.isEmpty && newItems.isEmpty {
                    return context.eventLoop.future(())
                }
                
                let changes = diff(old: oldItems, new: newItems)
                
                let insertChanges = changes.compactMap { $0.insert }
                let deleteChanges = changes.compactMap { $0.delete }
                let shouldNotify = !insertChanges.isEmpty || !deleteChanges.isEmpty
                
//                context.application.logger.info("===========================================")
//                context.application.logger.info("Should notify for ipad: \(shouldNotify)")
//                context.application.logger.info("Insert count ipad: \(insertChanges.count)")
//                context.application.logger.info("Delete count for ipad: \(deleteChanges.count)")
//                context.application.logger.info("===========================================")

                guard shouldNotify else {
                    return context.application.redis.set("ipad_products", toJSON: newItems)
                }
                
                var emails: [EventLoopFuture<Void>] = []
                let listOfEmails = context.application.notificationEmails.map { EmailAddress(email: $0) }

                let fromEmail = EmailAddress(
                    email: "no-reply@1991ebay.com",
                    name: "1991Ebay")
                
                if !insertChanges.isEmpty {
                    let emailTitle: String = "✅🍎🖥 IPAD thêm hàng!"
                    let emailContent: String = """
                    Thêm: [\(insertChanges.count)]<br/>
                    \(insertChanges.map {
                        """
                        - <a href="\($0.item.safeWebURL)">\($0.item.safeTitle)</a>
                        """
                    }.joined(separator: "<br/>"))
                        <br/><br/><br/>
                        List:<br/>
                        \(newItems.map { """
                        - <a href="\($0.safeWebURL)">\($0.safeTitle)</a>
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
                    try emails.append(context
                                    .application
                                    .sendgrid
                                    .client
                                    .send(email: email,
                                          on: context.eventLoop))
                }
                if !deleteChanges.isEmpty {
                    let emailTitle: String = "💥🍎🖥 IPAD hết hàng!"
                    let emailContent: String = """
                    Hết: [\(deleteChanges.count)]<br/>
                    \(deleteChanges.map {
                        """
                        -  <a href="\($0.item.safeWebURL)">\($0.item.safeTitle)</a>
                        """ }.joined(separator: "<br/>"))
                        <br/><br/><br/>
                        List:<br/>
                        \(newItems.map { """
                        - <a href="\($0.safeWebURL)">\($0.safeTitle)</a>
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
//                context.application.logger.info("sending \(emails.count) emails to \(context.application.notificationEmails)")
                return emails
                    .flatten(on: context.eventLoop)
                    .flatMap {
                        return context.application.redis.set("ipad_products", toJSON: newItems)
                    }
            }.flatMapErrorThrowing { error in
                context.application.logger.error("Failed seller scan for IPAD with error \(error)")
                return
            }
    }
}
