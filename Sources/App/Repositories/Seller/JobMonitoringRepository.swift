//
//  File.swift
//  
//
//  Created by Phan Tran on 13/06/2020.
//

import Foundation
import Vapor
import Fluent

protocol JobMonitoringRepository {
    func save(jobMonitoring: JobMonitoring) -> EventLoopFuture<Void>
    func getLast(jobName: String) -> EventLoopFuture<JobMonitoring?>
}

struct DatabaseJobMonitoringRepository: JobMonitoringRepository {
    let db: Database

    func save(jobMonitoring: JobMonitoring) -> EventLoopFuture<Void> {
        return jobMonitoring.save(on: self.db)
    }

    func getLast(jobName: String) -> EventLoopFuture<JobMonitoring?> {
        return JobMonitoring.query(on: self.db)
            .filter(\.$jobName == jobName)
            .sort(\.$createdAt, .descending)
            .first()
    }
}

struct JobMonitoringRepositoryFactory {
    var make: ((Request) -> JobMonitoringRepository)?
    
    mutating func use(_ make: @escaping ((Request) -> JobMonitoringRepository)) {
        self.make = make
    }
}

extension Application {
    private struct JobMonitoringRepositoryKey: StorageKey {
        typealias Value = JobMonitoringRepositoryFactory
    }
    
    var jobMonitorings: JobMonitoringRepositoryFactory {
        get {
            self.storage[JobMonitoringRepositoryKey.self] ?? .init()
        }
        set {
            self.storage[JobMonitoringRepositoryKey.self] = newValue
        }
    }
}

extension Request {
    var jobMonitorings: JobMonitoringRepository {
        self.application.jobMonitorings.make!(self)
    }
}
