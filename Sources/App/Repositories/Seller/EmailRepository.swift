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

struct AppFrontendURL: StorageKey {
    typealias Value = String
}

extension Application {
    var appFrontendURL: String? {
        get { self.storage[AppFrontendURL.self] }
        set { self.storage[AppFrontendURL.self] = newValue }
    }
}

protocol EmailRepositoryRepository {
    func sendItemAvailableEmail(for item: Item) throws -> EventLoopFuture<Void>
}

struct SendGridEmailRepositoryRepository: EmailRepositoryRepository {
    let appFrontendURL: String
    let client: SendGridClient
    let eventLoop: EventLoop

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
        
        let emailAddress = EmailAddress(email: "annavux@gmail.com")
        
        let emailConfig = Personalization(
            to: [emailAddress],
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

        return try self.client.send(email: email, on: self.eventLoop)
    }
}

struct EmailRepositoryRepositoryFactory {
    var make: ((Request) -> EmailRepositoryRepository)?
    
    mutating func use(_ make: @escaping ((Request) -> EmailRepositoryRepository)) {
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
    var emails: EmailRepositoryRepository {
        self.application.emails.make!(self)
    }
}
