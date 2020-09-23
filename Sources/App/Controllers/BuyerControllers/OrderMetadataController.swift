//
//  File.swift
//  
//
//  Created by Phan Tran on 28/05/2020.
//

import Foundation
import Vapor
import SwiftSoup

struct OrderMetadataController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let groupedRoutes = routes.grouped("orderMetadata")

        groupedRoutes.get("orderOptions", use: getOrderOptionsHandler)
        groupedRoutes.get("ebayItemInformation", use: getEbayItemInformationHandler)
        groupedRoutes.get("searchBySeller", use: searchItemsBySellerHandler)
        groupedRoutes.get("scanCount", use: getScanCountHandler)
    }

    private func getScanCountHandler(request: Request) throws -> Int {
        return request.application.scanCount
    }

    private func getEbayItemInformationHandler(request: Request) throws -> EventLoopFuture<EbayAPIItemOutput> {
        let itemID = try request.query.get(String.self, at: "itemID")
        return request.ebayAPIs.getItemDetails(itemID: itemID)
    }

    private func getOrderOptionsHandler(request: Request) throws -> EventLoopFuture<[OrderOption]> {
        return request
            .orderOptions
            .all()
    }

    private func searchItemsBySellerHandler(request: Request) throws -> EventLoopFuture<EbayAPIItemListOutput> {
        let input = try request.query.decode(SearchEbayItemsBySellerInput.self)
        return request.ebayAPIs.getItemDetails(
            seller: input.seller,
            keyword: input.keyword,
            offset: Int(input.itemOffset) ?? 0)
    }
}
