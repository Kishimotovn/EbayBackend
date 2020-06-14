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
    try app.queues.use(.redis(url: Environment.get("REDIS_URL") ?? "redis://127.0.0.1:32768"))
}
