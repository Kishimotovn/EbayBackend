//
//  repositories.swift
//  
//
//  Created by Phan Tran on 19/05/2020.
//

import Foundation
import Vapor
import JWT

public func setupRepositories(app: Application) throws {
    app.buyers.use { req in
        return DatabaseBuyerRepository(db: req.db)
    }
    app.buyerTokens.use { req in
        return DatabaseBuyerTokenRepository(db: req.db)
    }

    app.jwt.signers.use(JWTSigner.hs256(key: [UInt8]("Kishimotovn".utf8)))
}
