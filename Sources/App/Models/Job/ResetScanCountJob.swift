//
//  File.swift
//  
//
//  Created by Phan Tran on 23/09/2020.
//

import Foundation
import Vapor
import Queues

struct ResetScanCountJob: ScheduledJob {
    func run(context: QueueContext) -> EventLoopFuture<Void> {
        context.application.scanCount = 0
        return context.eventLoop.future()
    }
}
