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
    app.databases.use(.postgres(
        hostname: "ec2-54-146-4-66.compute-1.amazonaws.com",
        port: 5432,
        username: "ymtwkzhndbzcxg",
        password: "ea570d9b71b2075811e869a8b6d8b0f32613c224768e9500f080af678ca69789",
        database: "d5acg9sgiqcfkv",
        tlsConfiguration: TLSConfiguration.forClient(certificateVerification: .none)
    ), as: .psql)
//    if let databaseURL = Environment.process.DATABASE_URL {
//        try app.databases.use(.postgres(url: databaseURL), as: .psql)
//    } else {
//        app.databases.use(.postgres(
//            hostname: Environment.get("DATABASE_HOST") ?? "localhost",
//            username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
//            password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
//            database: Environment.get("DATABASE_NAME") ?? "ebay_db"
//        ), as: .psql)
//    }
    app.databases.middleware.use(JobMonitoringMiddleware(), on: .psql)
}

extension URL {
    func appending(_ queryItem: String, value: String?) -> URL {

        guard var urlComponents = URLComponents(string: absoluteString) else { return absoluteURL }

        // Create array of existing query items
        var queryItems: [URLQueryItem] = urlComponents.queryItems ??  []

        // Create query item
        let queryItem = URLQueryItem(name: queryItem, value: value)

        // Append the new query item in the existing query items array
        queryItems.append(queryItem)

        // Append updated query items array in the url component object
        urlComponents.queryItems = queryItems

        // Returns the url from new url components
        return urlComponents.url!
    }
}
