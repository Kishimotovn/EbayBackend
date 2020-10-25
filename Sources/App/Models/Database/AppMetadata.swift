//
//  File.swift
//  
//
//  Created by Phan Tran on 23/09/2020.
//

import Foundation
import Vapor
import Fluent

final class AppMetadata: Model, Content {
    static var schema: String = "app_metadata"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "scan_count")
    var scanCount: Int

    @OptionalField(key: "created_at")
    var createdAt: Date?
    

    init() { }

    init(scanCount: Int,
         date: Date) {
        self.scanCount = scanCount
        self.createdAt = date
    }
}
