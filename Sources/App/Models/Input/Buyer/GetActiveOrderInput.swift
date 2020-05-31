//
//  File.swift
//  
//
//  Created by Phan Tran on 28/05/2020.
//

import Foundation
import Vapor
import Fluent

struct GetActiveOrderInput: Decodable {
    var pageRequest: PageRequest
}
