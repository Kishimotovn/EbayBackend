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

    init() { }

    init(scanCount: Int) {
        self.scanCount = scanCount
    }
}
