//
//  File.swift
//  
//
//  Created by Phan Tran on 13/06/2020.
//

import Foundation
import Vapor
import Fluent
import Queues

struct TestJob: ScheduledJob {
    func run(context: QueueContext) -> EventLoopFuture<Void> {
        let jobMonitoringRepository = DatabaseJobMonitoringRepository(db: context.application.db)
        let jobMonitoring = JobMonitoring(jobName: self.name)
        return jobMonitoringRepository.save(jobMonitoring: jobMonitoring)
    }
}
