//
//  File.swift
//  
//
//  Created by Phan Tran on 24/05/2020.
//

import Foundation
import Fluent
import Vapor
import JWT

final class Seller: Model, Content {
    static var schema: String = "sellers"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Field(key: "password_hash")
    var passwordHash: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?

    @OptionalField(key: "avoided_ebay_sellers")
    var avoidedEbaySellers: [String]?

    @Siblings(through: SellerWarehouseAddress.self, from: \.$seller, to: \.$warehouse)
    var warehouseAddresses: [WarehouseAddress]

    @Children(for: \.$seller)
    var sellerWarehouseAddresses: [SellerWarehouseAddress]

    @Siblings(through: SellerItemSubscription.self, from: \.$seller, to: \.$item)
    var subscribedItems: [Item]
 
    init() { }

    init(name: String,
         passwordHash: String) {
        self.name = name
        self.passwordHash = passwordHash
    }
}

extension Seller: ModelAuthenticatable {
    static var usernameKey: KeyPath<Seller, Field<String>> = \.$name
    static var passwordHashKey: KeyPath<Seller, Field<String>> = \.$passwordHash

    func verify(password: String) throws -> Bool {
        return try Bcrypt.verify(password, created: self.passwordHash)
    }
}

extension Seller {
    struct AccessTokenPayload: JWTPayload {
        var issuer: IssuerClaim
        var issuedAt: IssuedAtClaim
        var exp: ExpirationClaim
        var sub: SubjectClaim

        init(issuer: String = "Metis-API",
             issuedAt: Date = Date(),
             expirationAt: Date = Date().addingTimeInterval(60*60*2),
             sellerID: Seller.IDValue) {
            self.issuer = IssuerClaim(value: issuer)
            self.issuedAt = IssuedAtClaim(value: issuedAt)
            self.exp = ExpirationClaim(value: expirationAt)
            self.sub = SubjectClaim(value: sellerID.description)
        }

        func verify(using signer: JWTSigner) throws {
            try self.exp.verifyNotExpired()
        }
    }

    func accessTokenPayload() throws -> AccessTokenPayload {
        return try AccessTokenPayload(sellerID: self.requireID())
    }
}

extension Seller {
    func generateToken() throws -> SellerToken {
        try .init(
            value: [UInt8].random(count: 16).base64,
            sellerID: self.requireID()
        )
    }
}
