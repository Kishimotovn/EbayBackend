//
//  File.swift
//  
//
//  Created by Phan Tran on 20/06/2020.
//

import Foundation
import Vapor

struct CreateWarehouseAddressesInput: Content {
    var warehouseAddresses: [CreateWarehouseAddressInput]
}
