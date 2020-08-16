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
    app.queues
        .schedule(UpdateQuantityJob())
        .minutely()
}
