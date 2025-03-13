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

public func redis(app: Application) throws {
    let urlString = Environment.get("REDIS_URL") ?? "redis://127.0.0.1:6379"
    let poolOptions = RedisConfiguration.PoolOptions(
        minimumConnectionCount: 1,
        connectionRetryTimeout: .minutes(4)
    )
    let configuration: RedisConfiguration
    
    if let url = URL(string: urlString), url.scheme == "rediss" {
        var config = TLSConfiguration.makeClientConfiguration()
        config.certificateVerification = .none
        
        configuration = try RedisConfiguration(
            url: Environment.get("REDIS_URL") ?? "redis://127.0.0.1:6379",
            tlsConfiguration: config,
            pool: poolOptions
        )
    } else {
        configuration = try RedisConfiguration(
            url: Environment.get("REDIS_URL") ?? "redis://127.0.0.1:6379",
            pool: poolOptions
        )
    }
    app.queues.use(.redis(configuration))
    app.redis.configuration = configuration
}
