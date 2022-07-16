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
        return ClientEbayAPIRepository(application: req.application,
                                       client: req.client,
                                       ebayAppID: req.application.ebayAppID ?? "",
                                       ebayAppSecret: req.application.ebayAppSecret ?? "")
    }
    app.sellerItemSubscriptions.use { req in
        return DatabaseSellerItemSubscriptionRepository(db: req.db)
    }
    app.jobMonitorings.use { req in
        return DatabaseJobMonitoringRepository(db: req.db)
    }
    app.emails.use { req in
        return SendGridEmailRepository(
            appFrontendURL: req.application.appFrontendURL ?? "",
            queue: req.queue,
            db: req.db,
            eventLoop: req.eventLoop
        )
    }
    app.buyerResetPasswordTokens.use { req in
        return DatabaseBuyerResetPasswordTokenRepository(db: req.db)
    }
    app.jwt.signers.use(JWTSigner.hs256(key: [UInt8]("Kishimotovn".utf8)))
    app.sellerTokens.use { req in
        return DatabaseSellerTokenRepository(db: req.db)
    }
    app.sellerItemFeatured.use { DatabaseSellerItemFeaturedRepository(db: $0.db) }
    app.appMetadatas.use {
        DatabaseAppMetadataRepository(db: $0.db)
    }
    app.sellerSubscriptions.use {
        DatabaseSellerSellerSubscriptionRepository(db: $0.db)
    }
    app.trackedItems.use {
        DatabaseTrackedItemRepository(db: $0.db)
    }
    app.buyerTrackedItems.use {
        DatabaseBuyerTrackedItemRepository(db: $0.db)
    }
    app.fileStorages.use{ req in
        AzureStorageRepository(client: req.client, logger: req.logger, storageName: req.application.azureStorageName ?? "", accessKey: req.application.azureStorageKey ?? "")
    }

    app.ebayAppID = Environment.process.EBAY_APP_ID
    app.ebayAppSecret = Environment.process.EBAY_APP_SECRET
    app.appFrontendURL = Environment.process.FRONTEND_URL
    app.scanInterval = Int(Environment.process.SCAN_INTERVAL ?? "") ?? 5
    app.notificationEmails = (Environment.process.NOTIFICATION_EMAILS ?? "minhdung910@gmail.com,chonusebay@gmail.com").components(separatedBy: ",")
    app.updateSellerBatchCount = Int(Environment.process.UPDATE_SELLER_BATCH_COUNT ?? "") ?? 2
    app.ipadScanInterval = Int(Environment.process.IPAD_SCAN_INTERVAL ?? "") ?? 5
    app.azureStorageName = Environment.process.AZURE_STORAGE_NAME
    app.azureStorageKey = Environment.process.AZURE_STORAGE_ACCESS_KEY

    if (Environment.process.SENDGRID_API_KEY != nil) {
        app.sendgrid.initialize()
    }
}
