//
//  File.swift
//  
//
//  Created by Phan Tran on 23/05/2020.
//

import Foundation
import Fluent
import Vapor

final class WarehouseAddress: Model, @unchecked Sendable, Content {
    static let schema: String = "warehouse_addresses"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "address_line_1")
    var addressLine1: String

    @OptionalField(key: "address_line_2")
    var addressLine2: String?

    @Field(key: "city")
    var city: String

    @Field(key: "state")
    var state: String

    @Field(key: "zip_code")
    var zipCode: String

    @Field(key: "phone_number")
    var phoneNumber: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() { }

    init(addressLine1: String,
         addressLine2: String? = nil,
         city: String,
         state: String,
         zipCode: String,
         phoneNumber: String) {
        self.addressLine1 = addressLine1
        self.addressLine2 = addressLine2
        self.city = city
        self.state = state
        self.zipCode = zipCode
        self.phoneNumber = phoneNumber
    }
}
