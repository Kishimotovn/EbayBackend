//
//  File.swift
//  
//
//  Created by Phan Tran on 14/06/2020.
//

import Foundation
import Vapor
import Fluent
import SendGrid
import Queues

struct AppFrontendURL: StorageKey {
    typealias Value = String
}

extension Application {
    var appFrontendURL: String? {
        get { self.storage[AppFrontendURL.self] }
        set { self.storage[AppFrontendURL.self] = newValue }
    }
}

protocol EmailRepository {
    func sendItemAvailableEmail(for item: Item) throws -> EventLoopFuture<Void>
    func sendOrderUpdateEmail(for order: Order) throws -> EventLoopFuture<Void>
    func sendTrackedItemUpdateEmail(for item: TrackedItem) throws -> EventLoopFuture<Void>
    func sendTrackedItemsUpdateEmail(for items: [TrackedItem]) throws -> EventLoopFuture<Void>
    func sendResetPasswordEmail(for buyer: Buyer,
                                resetPasswordToken: BuyerResetPasswordToken) throws -> EventLoopFuture<Void>
}

struct SendGridEmailRepository: EmailRepository {
    let appFrontendURL: String
    let queue: Queue
    let db: Database
    let eventLoop: EventLoop

    func sendTrackedItemsUpdateEmail(for items: [TrackedItem]) throws -> EventLoopFuture<Void> {
        let itemIDs = try items.map { try $0.requireID() }
            
        return BuyerTrackedItem.query(on: self.db)
            .join(siblings: \.$trackedItems)
            .filter(TrackedItem.self, \.$id ~~ itemIDs)
            .all()
            .tryFlatMap { buyerItems in
                let groupedBuyerItems = Dictionary.init(grouping: buyerItems, by: \.$buyer.id)

                return try groupedBuyerItems.keys.map { buyerID in
                    let buyerItems = groupedBuyerItems[buyerID] ?? []

                    guard let buyerItem = buyerItems.first else {
                        return self.eventLoop.future()
                    }

                    let email = buyerItem.buyer.email

                    func message(for item: BuyerTrackedItem) -> String? {
                        guard let updatedItem = try? item.joined(TrackedItem.self) else{
                            return nil
                        }
                        
                        let state: String
                        switch updatedItem.state {
                        case .delivered:
                            state = "đã giao"
                        case .flyingBack:
                            state = "đang trên đường vận chuyển từ US -> VN"
                        case .receivedAtUSWarehouse:
                            state = "về tới kho US"
                        case .receivedAtVNWarehouse:
                            state = "về tới kho VN"
                        default:
                            return nil
                        }
                        
                        if !item.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            return "- \(item.note) (Mã tracking: \(item.trackingNumber)) đã được xác nhận \(state)."
                        } else {
                            return "- Mặt hàng với mã tracking: \(item.trackingNumber) đã được xác nhận về \(state)."
                        }
                    }

                    let messages = buyerItems.compactMap { item in
                        message(for: item)
                    }.joined(separator: "<br/>")

                    return try self.sendEmail(to: email, title: "🎉🥳 Hàng đã về tới kho!", content: messages)
                }.flatten(on: self.eventLoop)
            }
    }

    func sendTrackedItemUpdateEmail(for item: TrackedItem) throws -> EventLoopFuture<Void> {
        return try BuyerTrackedItem.query(on: self.db)
            .join(siblings: \.$trackedItems)
            .filter(TrackedItem.self, \.$id == item.requireID())
            .all()
            .tryFlatMap { buyerItems in
                return try buyerItems.map { buyerItem in
                    let email = buyerItem.buyer.email
                    let content: String
                    
                    let state: String
                    switch item.state {
                    case .delivered:
                        state = "đã giao"
                    case .flyingBack:
                        state = "đang trên đường vận chuyển từ US -> VN"
                    case .receivedAtUSWarehouse:
                        state = "về tới kho US"
                    case .receivedAtVNWarehouse:
                        state = "về tới kho VN"
                    default:
                        return self.eventLoop.future()
                    }
                    
                    if !buyerItem.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        content = "\(buyerItem.note) (Mã tracking: \(buyerItem.trackingNumber)) đã được xác nhận \(state)."
                    } else {
                        content = "Mặt hàng với mã tracking: \(buyerItem.trackingNumber) đã được xác nhận \(state)."
                    }
                    return try self.sendEmail(to: email, title: "🎉🥳 Hàng đã về tới kho!", content: content)
                }.flatten(on: self.eventLoop)
            }
    }

    func sendResetPasswordEmail(for buyer: Buyer,
                                resetPasswordToken: BuyerResetPasswordToken) throws -> EventLoopFuture<Void> {
        let emailTitle = "Reset Mật khẩu"
        let emailContent = """
        <p>Để reset lại mật khẩu, vui lòng click vào <a clicktracking=off href="\(self.appFrontendURL)/resetpassword?token=\(resetPasswordToken.value)">link</a>.</p>
        """
        
        return try self.sendEmail(to: buyer.email,
                                  title: emailTitle,
                                  content: emailContent)
    }

    func sendOrderUpdateEmail(for order: Order) throws -> EventLoopFuture<Void> {
        return order.$buyer.load(on: self.db)
            .tryFlatMap {
                let emailTitle = "Đơn hàng đã được update"
                let orderState: String
                switch order.state {
                case .cart:
                    orderState = "Giỏ hàng"
                case .buyerVerificationRequired:
                    orderState = "Đợi xác thực tài khoản"
                case .delivered:
                    orderState = "Đã giao"
                case .failed:
                    orderState = "Huỷ"
                case .inProgress:
                    orderState = "Đang xử lí"
                case .registered:
                    orderState = "Đã đăng kí"
                case .stuck:
                    orderState = "Tắc"
                case .waitingForTracking:
                    orderState = "Đợi tracking"
                case .priceChanged:
                    orderState = "Giá hàng thay đổi"
                }
                let emailContent = """
                <p>Đơn hàng mã số \(order.orderIndex) đã được chuyển sang trạng thái: \(orderState)</p> Truy cập <a href="\(self.appFrontendURL)/orders">link</a> để check đơn ngay.</p>
                """

                return try self.sendEmail(to: order.buyer.email,
                                          title: emailTitle,
                                          content: emailContent)
        }
    }

    func sendItemAvailableEmail(for item: Item) throws -> EventLoopFuture<Void> {
        let isInStock = item.lastKnownAvailability == true

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
        
        return try self.sendEmail(to: "minhdung910@gmail.com", title: emailTitle, content: emailContent)
    }

    private func sendEmail(to address: String, title: String, content: String) throws -> EventLoopFuture<Void> {
        let payload = EmailJobPayload(destination: address,
                                       title: title, content: content)
        if Environment.get("REDIS_URL") != nil {
            return self.queue.dispatch(EmailJob.self,
                payload,
                maxRetryCount: 3)
        } else {
            return self.eventLoop.future()
        }
    }
}

struct EmailRepositoryRepositoryFactory {
    var make: ((Request) -> EmailRepository)?
    
    mutating func use(_ make: @escaping ((Request) -> EmailRepository)) {
        self.make = make
    }
}

extension Application {
    private struct EmailRepositoryRepositoryKey: StorageKey {
        typealias Value = EmailRepositoryRepositoryFactory
    }

    var emails: EmailRepositoryRepositoryFactory {
        get {
            self.storage[EmailRepositoryRepositoryKey.self] ?? .init()
        }
        set {
            self.storage[EmailRepositoryRepositoryKey.self] = newValue
        }
    }
}

extension Request {
    var emails: EmailRepository {
        self.application.emails.make!(self)
    }
}
