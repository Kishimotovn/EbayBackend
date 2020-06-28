//
//  File.swift
//  
//
//  Created by Phan Tran on 13/06/2020.
//

import Foundation
import Vapor
import QueuesRedisDriver
import Queues

public func jobs(app: Application) throws {
    let emailJob = EmailJob()
    app.queues.add(emailJob)

    for i in 0..<12 {
        let minute = i*5
        app.queues.schedule(UpdateQuantityJob())
            .hourly().at(.init(integerLiteral: minute))
    }
}
