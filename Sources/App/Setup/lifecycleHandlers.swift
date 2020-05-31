//
//  File.swift
//  
//
//  Created by Phan Tran on 26/05/2020.
//

import Foundation
import Vapor

public func lifecycleHandlers(app: Application) throws {
    app.lifecycle.use(MasterSellerRegistration())
}
