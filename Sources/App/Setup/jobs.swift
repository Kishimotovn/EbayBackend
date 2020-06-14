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
    app.queues.schedule(UpdateQuantityJob())
        .hourly().at(0)

    app.queues.schedule(UpdateQuantityJob())
        .hourly().at(10)

    app.queues.schedule(UpdateQuantityJob())
        .hourly().at(20)

    app.queues.schedule(UpdateQuantityJob())
        .hourly().at(30)

    app.queues.schedule(UpdateQuantityJob())
        .hourly().at(40)

    app.queues.schedule(UpdateQuantityJob())
        .hourly().at(50)

    try app.queues.startScheduledJobs()
}
