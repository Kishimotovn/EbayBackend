//
//  databases.swift
//  
//
//  Created by Phan Tran on 19/05/2020.
//

import Foundation
import Vapor
import Fluent
import FluentPostgresDriver

public func databases(app: Application) throws {
    if let databaseURL = Environment.process.DATABASE_URL {
        try app.databases.use(.postgres(url: databaseURL), as: .psql)
    } else {
        app.databases.use(.postgres(
            hostname: Environment.get("DATABASE_HOST") ?? "localhost",
            username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
            password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
            database: Environment.get("DATABASE_NAME") ?? "ebay_db"
        ), as: .psql)
    }
    app.databases.middleware.use(JobMonitoringMiddleware(), on: .psql)
}
