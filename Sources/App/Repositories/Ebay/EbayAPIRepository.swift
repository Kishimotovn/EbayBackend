//
//  File.swift
//  
//
//  Created by Phan Tran on 30/05/2020.
//

import Foundation
import Vapor
import Fluent

protocol EbayAPIRepository {
    func getItemDetails(itemID: String) -> EventLoopFuture<EbayAPIItemOutput>
}

struct ClientEbayAPIRepository: EbayAPIRepository {
    let client: Client
    let ebayAppID: String

    func getItemDetails(itemID: String) -> EventLoopFuture<EbayAPIItemOutput> {
        let url = URI(
            scheme: "https",
            host: "open.api.ebay.com",
            path: "shopping")
        return self.client.get(url, headers: ["Accept": "application/json"]) { req in
            try req.query.encode([
                "callname": "GetSingleItem",
                "responseencoding": "JSON",
                "appid": self.ebayAppID,
                "version": "1141",
                "ItemID": itemID,
                "siteid": "0",
                "IncludeSelector": "ShippingCosts,TextDescription,Details,Description"
            ])
        }.flatMapThrowing { response -> EbayAPIGetSingleItemResponse in
            var processedResponse = response
            processedResponse.headers.remove(name: .contentType)
            processedResponse.headers.add(name: .contentType, value: "application/json")
            return try processedResponse.content.decode(EbayAPIGetSingleItemResponse.self)
        }.flatMapThrowing { itemResponse in
            let item = itemResponse.Item

            guard item.Site == "US" else {
                throw Abort(.badRequest)
            }

            let normalizedShippingPrice = Int((item.ShippingCostSummary.ShippingServiceCost?.Value) ?? 0.0 * 100.0)
            let normalizedOriginalPrice = Int(item.ConvertedCurrentPrice.Value * 100.0)
            return EbayAPIItemOutput(
                itemID: item.ItemID,
                name: item.Title,
                imageURL: item.PictureURL.first ?? "",
                condition: item.ConditionDisplayName,
                shippingPrice: normalizedShippingPrice,
                originalPrice: normalizedOriginalPrice,
                sellerName: item.Seller?.UserID,
                sellerFeedbackCount: item.Seller?.FeedbackScore,
                sellerScore: item.Seller?.PositiveFeedbackPercent)
        }
    }
}

struct EbayAPIGetSingleItemResponse: Content {
    struct Item: Content {
        struct Seller: Content {
            var UserID: String
            var FeedbackScore: Int
            var PositiveFeedbackPercent: Double
        }
        struct Price: Content {
            var Value: Double
            var CurrencyID: String
        }
        enum ListingStatus: String, Codable {
            case Active
            case Completed
            case Ended
        }
        struct ShippingCostSummary: Content {
            var ShippingServiceCost: Price?
        }
        struct DiscountPriceInfo: Content {
            var OriginalRetailPrice: Price?
        }

        var Description: String?
        var ItemID: String
        var PictureURL: [String]
        var Seller: Seller?
        var ConvertedCurrentPrice: Price
        var ListingStatus: ListingStatus
        var ShipToLocations: [String]?
        var Location: String
        var Title: String
        var ShippingCostSummary: ShippingCostSummary
        var Subtitle: String?
        var ConditionDisplayName: String?
        var DiscountPriceInfo: DiscountPriceInfo?
        var Site: String
    }

    var Item: Item
}

struct EbayAPIRepositoryFactory {
    var make: ((Request) -> EbayAPIRepository)?
    
    mutating func use(_ make: @escaping ((Request) -> EbayAPIRepository)) {
        self.make = make
    }
}

extension Application {
    private struct EbayAPIRepositoryKey: StorageKey {
        typealias Value = EbayAPIRepositoryFactory
    }
    
    var ebayAPIs: EbayAPIRepositoryFactory {
        get {
            self.storage[EbayAPIRepositoryKey.self] ?? .init()
        }
        set {
            self.storage[EbayAPIRepositoryKey.self] = newValue
        }
    }
}

extension Request {
    var ebayAPIs: EbayAPIRepository {
        self.application.ebayAPIs.make!(self)
    }
}
