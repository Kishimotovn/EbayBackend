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

    let interval = app.scanInterval
    for i in 0..<(60/interval) {
        let minute = i*interval
        app.queues.schedule(UpdateQuantityJob())
            .hourly().at(.init(integerLiteral: minute))
    }
}
