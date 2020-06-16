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
    for i in 0..<12 {
        let minute = i*5
        app.queues.schedule(UpdateQuantityJob())
            .hourly().at(.init(integerLiteral: minute))
    }
    
    app.queues.schedule(TestJob())
        .minutely()
        .at(0)

//    try app.queues.startScheduledJobs()
}
