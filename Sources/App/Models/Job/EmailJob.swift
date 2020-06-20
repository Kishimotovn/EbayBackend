//
//  File.swift
//  
//
//  Created by Phan Tran on 19/06/2020.
//

import Foundation
import Vapor
import Fluent
import Queues
import SendGrid

struct EmailJobPayload: Codable {
    var destination: String
    var title: String
    var content: String
}

struct EmailJob: Job {
    typealias Payload = EmailJobPayload

    func dequeue(_ context: QueueContext, _ payload: EmailJobPayload) -> EventLoopFuture<Void> {
        let emailAddress = EmailAddress(email: payload.destination)
        
        let emailConfig = Personalization(
            to: [emailAddress],
            subject: payload.title)

        let fromEmail = EmailAddress(
            email: "no-reply@1991ebay.com",
            name: "1991Ebay")
        
        let email = SendGridEmail(
            personalizations: [emailConfig],
            from: fromEmail,
            content: [
              ["type": "text/html",
               "value": payload.content]
            ])

        do {
            return try context
                .application
                .sendgrid
                .client
                .send(email: email,
                      on: context.eventLoop)
        } catch let error {
            return context.eventLoop.makeFailedFuture(error)
        }
    }
}
