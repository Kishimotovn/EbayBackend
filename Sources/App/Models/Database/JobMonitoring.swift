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
