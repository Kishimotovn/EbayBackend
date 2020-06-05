//
//  File.swift
//  
//
//  Created by Phan Tran on 04/06/2020.
//

import Foundation
import Vapor

struct CreateWarehouseAddressInput: Content {
    var name: String
    var addressLine1: String
    var addressLine2: String?
    var city: String
    var state: String
    var zipCode: String
    var phoneNumber: String
}

extension CreateWarehouseAddressInput {
    func warehouseAddress() -> WarehouseAddress {
        return WarehouseAddress(addressLine1: self.addressLine1,
                                addressLine2: self.addressLine2,
                                city: self.city,
                                state: self.state,
                                zipCode: self.zipCode,
                                phoneNumber: self.phoneNumber)
    }
}
