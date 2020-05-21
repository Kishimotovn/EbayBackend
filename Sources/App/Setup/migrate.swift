//
//  migrate.swift
//  
//
//  Created by Phan Tran on 19/05/2020.
//

import Foundation
import Vapor

public func migrate(app: Application) throws {
    app.migrations.add(CreateBuyers())
    app.migrations.add(CreateBuyerTokens())
}
