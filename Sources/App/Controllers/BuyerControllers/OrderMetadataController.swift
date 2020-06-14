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
}
