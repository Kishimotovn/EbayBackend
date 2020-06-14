//
//  File.swift
//  
//
//  Created by Phan Tran on 13/06/2020.
//

import Foundation
import Fluent

struct CreateJobMonitorings: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(JobMonitoring.schema)
            .id()
            .field("job_name", .string, .required)
            .field("created_at", .datetime)
            .field("finished_at", .datetime)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(JobMonitoring.schema).delete()
    }
}
