//
//  repositories.swift
//  
//
//  Created by Phan Tran on 19/05/2020.
//

import Foundation
import Vapor
import JWT
import SendGrid

public func setupRepositories(app: Application) throws {
    app.buyers.use { req in
        return DatabaseBuyerRepository(db: req.db)
    }
    app.buyerTokens.use { req in
        return DatabaseBuyerTokenRepository(db: req.db)
    }
    app.items.use { req in
        return DatabaseItemRepository(db: req.db)
    }
    app.orders.use { req in
        return DatabaseOrderRepository(db: req.db)
    }
    app.orderItems.use { req in
        return DatabaseOrderItemRepository(db: req.db)
    }
    app.sellers.use { req in
        return DatabaseSellerRepository(db: req.db)
    }
    app.warehouseAddresses.use { req in
        return DatabaseWarehouseAddressRepository(db: req.db)
    }
    app.buyerWarehouseAddresses.use { req in
        return DatabaseBuyerWarehouseAddressRepository(db: req.db)
    }
    app.orderOptions.use { req in
        return DatabaseOrderOptionRepository(db: req.db)
    }
    app.sellerWarehouseAddresses.use { req in
        return DatabaseSellerWarehouseAddressRepository(db: req.db)
    }
    app.orderItemReceipts.use { req in
        return DatabaseOrderItemReceiptRepository(db: req.db)
    }
    app.sellerAnalytics.use { req in
        return DatabaseSellerAnalyticsRepository(db: req.db)
    }
    app.ebayAPIs.use { req in
        return ClientEbayAPIRepository(client: req.client,
                                       ebayAppID: req.application.ebayAppID ?? "",
                                       ebayAppSecret: req.application.ebayAppSecret ?? "")
    }
    app.sellerItemSubscriptions.use { req in
        return DatabaseSellerItemSubscriptionRepository(db: req.db)
    }
    app.jobMonitorings.use { req in
        return DatabaseJobMonitoringRepository(db: req.db)
    }
    app.jwt.signers.use(JWTSigner.hs256(key: [UInt8]("Kishimotovn".utf8)))

    app.ebayAppID = Environment.process.EBAY_APP_ID
    app.ebayAppSecret = Environment.process.EBAY_APP_SECRET
    app.appFrontendURL = Environment.process.FRONTEND_URL
    
    app.sendgrid.initialize()
}
