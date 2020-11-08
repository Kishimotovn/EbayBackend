//
//  migrate.swift
//  
//
//  Created by Phan Tran on 19/05/2020.
//

import Foundation
import Vapor

public func migrate(app: Application) throws {
    app.migrations.add(CreateBuyers())
    app.migrations.add(CreateBuyerTokens())
    app.migrations.add(CreateSellers())
    app.migrations.add(CreateSellerTokens())
    app.migrations.add(CreateWarehouseAddresses())
    app.migrations.add(CreateBuyerWarehouseAddresses())
    app.migrations.add(CreateSellerWarehouseAddresses())
    app.migrations.add(CreateItems())
    app.migrations.add(CreateItemDiscounts())
    app.migrations.add(CreateOrderOptions())
    app.migrations.add(CreateOrders())
    app.migrations.add(CreateOrderItems())
    app.migrations.add(CreateOrderItemReceipts())
    app.migrations.add(CreateMasterSeller())
    app.migrations.add(CreateDefaultOrderOptions())
    app.migrations.add(CreateSellerItemSubscriptions())
    app.migrations.add(CreateJobMonitorings())
    app.migrations.add(AddVerifiedAtToBuyer())
    app.migrations.add(CreateBuyerResetPasswordTokens())
    app.migrations.add(AddFurtherDiscountDetectedToOrderItem())
    app.migrations.add(AddVolumeDiscountsToOrderItems())
    app.migrations.add(AddAcceptedPriceAndUpdatedPriceToOrderItem())
    app.migrations.add(AddAvoidedEbaySellersToSeller())
    app.migrations.add(AddScanIntervalToSellerItemSubscription())
    app.migrations.add(AddDeletedAtToSellerItemSubscription())
    app.migrations.add(AddCustomNameToSellerItemSubscription())
    app.migrations.add(CreateSellerItemFeatured())
    app.migrations.add(AddAppMetadata())
    app.migrations.add(AddIsFromFeaturedToOrderItem())
    app.migrations.add(AddPriceToSellerItemFeatured())
    app.migrations.add(CreateSellerSellerSubscriptions())
    app.migrations.add(AddCreatedAtToAppMetaData())
    app.migrations.add(AddIsEnabledToSellerItemSubscription())
    app.migrations.add(AddIsEnabledToSellerSellerSubscription())
}
