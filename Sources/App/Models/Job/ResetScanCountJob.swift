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
        let appMetaDatas = DatabaseAppMetadataRepository(db: context.application.db)
        return appMetaDatas.setScanCount(0)
    }
}
