//
//  File.swift
//  
//
//  Created by Phan Tran on 24/09/2020.
//

import Foundation
import Vapor
import Fluent

protocol AppMetadataRepository {
    func getScanCount() -> EventLoopFuture<Int>
    func setScanCount(_ count: Int) -> EventLoopFuture<Void>
    func incrementScanCount() -> EventLoopFuture<Void>
}

struct DatabaseAppMetadataRepository: AppMetadataRepository {
    let db: Database

    func getScanCount() -> EventLoopFuture<Int> {
        return AppMetadata
            .query(on: self.db)
            .first()
            .map { metaData in
                return metaData?.scanCount ?? 0
            }
    }

    func setScanCount(_ count: Int) -> EventLoopFuture<Void> {
        return AppMetadata
            .query(on: self.db)
            .first()
            .flatMap { metaData in
                let targetMetaData: AppMetadata
                if let metaData = metaData {
                    targetMetaData = metaData
                } else {
                    targetMetaData = AppMetadata(scanCount: 0)
                }
                targetMetaData.scanCount = count
                return targetMetaData.save(on: self.db)
            }
    }

    func incrementScanCount() -> EventLoopFuture<Void> {
        return AppMetadata
            .query(on: self.db)
            .first()
            .flatMap { metaData in
                let targetMetaData: AppMetadata
                if let metaData = metaData {
                    targetMetaData = metaData
                } else {
                    targetMetaData = AppMetadata(scanCount: 0)
                }
                targetMetaData.scanCount += 1
                return targetMetaData.save(on: self.db)
            }
    }
}

struct AppMetadataRepositoryFactory {
    var make: ((Request) -> AppMetadataRepository)?
    
    mutating func use(_ make: @escaping ((Request) -> AppMetadataRepository)) {
        self.make = make
    }
}

extension Application {
    private struct AppMetadataRepositoryKey: StorageKey {
        typealias Value = AppMetadataRepositoryFactory
    }
    
    var appMetadatas: AppMetadataRepositoryFactory {
        get {
            self.storage[AppMetadataRepositoryKey.self] ?? .init()
        }
        set {
            self.storage[AppMetadataRepositoryKey.self] = newValue
        }
    }
}

extension Request {
    var appMetadatas: AppMetadataRepository {
        self.application.appMetadatas.make!(self)
    }
}
