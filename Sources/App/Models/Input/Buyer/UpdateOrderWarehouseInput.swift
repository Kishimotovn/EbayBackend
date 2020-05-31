//
//  File.swift
//  
//
//  Created by Phan Tran on 27/05/2020.
//

import Foundation
import Vapor

struct WarehouseAddressInput: Content {
    var name: String
    var addressLine1: String
    var addressLine2: String?
    var city: String
    var state: String
    var zipCode: String
    var phoneNumber: String

    func warehouseAddress() -> WarehouseAddress {
        return WarehouseAddress(
            addressLine1: self.addressLine1,
            addressLine2: self.addressLine2,
            city: self.city,
            state: self.state,
            zipCode: self.zipCode,
            phoneNumber: self.phoneNumber)
    }
}

struct UpdateOrderWarehouseInput: Content {
    var existingWarehouseID: WarehouseAddress.IDValue?
    var newWarehouse: WarehouseAddressInput?
}
