//
//  File.swift
//  
//
//  Created by Phan Tran on 13/06/2020.
//

import Foundation
import Vapor
import Fluent

final class JobMonitoring: Model, Content {
    static var schema: String = "job_monitoring"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "job_name")
    var jobName: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Field(key: "finished_at")
    var finishedAt: Date?

    init() { }

    init(jobName: String) {
        self.jobName = jobName
    }
}

struct JobMonitoringMiddleware: ModelMiddleware {
    func create(model: JobMonitoring, on db: Database, next: AnyModelResponder) -> EventLoopFuture<Void> {
        return next.create(model, on: db).flatMap {
            return JobMonitoring.query(on: db).count()
        }.flatMap { jobCount in
            if jobCount >= 7000 {
                return JobMonitoring
                    .query(on: db)
                    .sort(\.$createdAt, .ascending)
                    .limit(5000)
                    .delete()
            } else {
                return db.eventLoop.future()
            }
        }
    }
}
