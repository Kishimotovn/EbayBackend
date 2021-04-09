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
    let configuration = try RedisConfiguration(url: Environment.get("REDIS_URL") ?? "redis://127.0.0.1:32768", pool: .init(connectionRetryTimeout: .minutes(4)))
    app.queues.use(.redis(configuration))
}
