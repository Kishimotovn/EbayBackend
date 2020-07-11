//
//  File.swift
//  
//
//  Created by Phan Tran on 30/05/2020.
//

import Foundation
import Vapor
import Fluent
import SwiftSoup

protocol EbayAPIRepository {
    func getItemDetails(itemID: String) -> EventLoopFuture<EbayAPIItemOutput>
    func getItemDetails(ebayItemID: String) -> EventLoopFuture<EbayAPIItemOutput>
}

class ClientEbayAPIRepository: EbayAPIRepository {
    let client: Client
    let ebayAppID: String
    let ebayAppSecret: String
    var tokenExpiryDate: Date?
    var currentToken: EbayToken?
    var currentRefreshTokenCall: EventLoopFuture<Void>?

    init(client: Client, ebayAppID: String, ebayAppSecret: String) {
        self.client = client
        self.ebayAppID = ebayAppID
        self.ebayAppSecret = ebayAppSecret
    }

    func getItemDetails(ebayItemID: String) -> EventLoopFuture<EbayAPIItemOutput> {
        return self.refreshTokenToken()
            .flatMap { () -> EventLoopFuture<ClientResponse> in
                let url = URI(
                    scheme: "https",
                    host: "api.ebay.com",
                    path: "buy/browse/v1/item/\(ebayItemID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!)")
                return self.client.get(
                    url,
                    headers: [
                        "Accept": "application/json",
                        "X-EBAY-C-MARKETPLACE-ID": "EBAY_US",
                        "Authorization": "Bearer \(self.currentToken?.accessToken ?? "")"
                ])
            }
        .tryFlatMap { response throws -> EventLoopFuture<EbayAPIItemOutput> in
            let item = try response.content.decode(EbayGetItemResponse.self)
            let shippingPrice = item.shippingOptions.first?.shippingCost.value?.currencyValue() ?? 0.0

            let normalizedShippingPrice = Int(truncating: (shippingPrice * 100) as NSNumber)

            let itemPrice = item.price.value?.currencyValue() ?? 0.0
            let normalizedOriginalPrice = Int(truncating: (itemPrice * 100.0) as NSNumber)
            let endDateString = item.itemEndDate
            let formatter = ISO8601DateFormatter()
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            let endDate = formatter.date(from: endDateString ?? "")

            var quantityLeft = "N/A"
            if let exactQuantity = item.estimatedAvailabilities?.first?.estimatedAvailableQuantity {
                quantityLeft = "\(exactQuantity)"
            } else if let estimatedQuantity = item.estimatedAvailabilities?.first?.availabilityThreshold {
                quantityLeft = "> \(estimatedQuantity)"
            }

            var furtherDiscountAmount: EventLoopFuture<(Int?, [VolumeDiscount]?)> = self.client.eventLoop.makeSucceededFuture((nil, nil))
            
            if let coupon = item
                .availableCoupons?
                .sorted(by: { (lhs: EbayGetItemResponse.AvailableCoupon, rhs: EbayGetItemResponse.AvailableCoupon) -> Bool in
                    let lhsAmount: Decimal = lhs.discountAmount?.value?.currencyValue() ?? Decimal(0)
                    let rhsAmount: Decimal = rhs.discountAmount?.value?.currencyValue() ?? Decimal(0)
                    return lhsAmount < rhsAmount })
                .first {
                    if let couponAmount = coupon.discountAmount?.value?.currencyValue() {
                        let directDiscount = Int(truncating: (couponAmount * 100) as NSNumber)
                        furtherDiscountAmount = self.client.eventLoop.makeSucceededFuture((directDiscount, nil))
                    }
            } else {
                furtherDiscountAmount = self.getFurtherDiscountFromWebPage(
                                            urlString: item.itemWebUrl,
                                            from: normalizedOriginalPrice)
            }

            return furtherDiscountAmount.map { directDiscount, volumeDiscounts in
                let detected = (directDiscount != nil && directDiscount! > 0) || (volumeDiscounts?.isEmpty == false)
                return EbayAPIItemOutput(
                    itemID: item.itemId,
                    name: item.title,
                    imageURL: item.image.imageUrl,
                    itemURL: item.itemWebUrl,
                    condition: item.condition,
                    shippingPrice: normalizedShippingPrice,
                    originalPrice: normalizedOriginalPrice,
                    sellerName: item.seller.username,
                    sellerFeedbackCount: item.seller.feedbackScore,
                    sellerScore: Double(item.seller.feedbackPercentage),
                    itemEndDate: endDate,
                    quantityLeft: quantityLeft,
                    volumeDiscounts: volumeDiscounts,
                    furtherDiscountAmount: directDiscount,
                    furtherDiscountDetected: detected
                )
            }
        }
    }

    func getItemDetails(itemID: String) -> EventLoopFuture<EbayAPIItemOutput> {
        return self.refreshTokenToken()
            .flatMap {
                return self.searchItem(itemID: itemID)
            }.flatMap { ebayItemID -> EventLoopFuture<String?> in
                if let id = ebayItemID {
                    return self.client.eventLoop.makeSucceededFuture(id)
                } else {
                    return self.searchLegacyItem(itemID: itemID)
                }
            }.flatMap { ebayItemID -> EventLoopFuture<String?> in
                if let id = ebayItemID {
                    return self.client.eventLoop.makeSucceededFuture(id)
                } else {
                    return self.searchItem(epid: itemID)
                }
            }
            .unwrap(or: Abort(.notFound, reason: "Yêu cầu không hợp lệ"))
            .flatMap { ebayItemID -> EventLoopFuture<EbayAPIItemOutput> in
                return self.getItemDetails(ebayItemID: ebayItemID)
            }
    }

    private func getFurtherDiscountFromWebPage(urlString: String, from price: Int) -> EventLoopFuture<(Int?, [VolumeDiscount]?)> {
        let uri = URI(string: urlString)

        return self.client.get(uri)
            .map { response -> (Int?, [VolumeDiscount]?) in
                do {
                    if let body = response.body {
                        let html = String(buffer: body)
                        let doc: Document = try! SwiftSoup.parse(html)
                        var directDiscount: Int?

                        if let element = try doc.select(".smeOfferMsg").first()?.text().lowercased() {
                            let regex = try NSRegularExpression(pattern: "extra (\\d+)% off")
                            let range = NSRange(location: 0, length: element.utf16.count)
                            if let groups = regex
                                .firstMatch(in: element, options: [], range: range)?
                                .groups(testedString: element),
                                let percentGroup = groups.get(at: 1),
                                let percentage = Double(percentGroup) {
                                let directDiscountAmount = Int(Double(price) * percentage/100.0)
                                directDiscount = directDiscountAmount
                            }
                        }

                        var volumeDiscounts: [VolumeDiscount]?
                        if html.contains("volumePricingOfferModel") {
                            let volumnOfferRegex = try NSRegularExpression(pattern: "\"volumePricingOfferModel\":\\[[^\\]]*\\]")
                            let range = NSRange(location: 0, length: html.utf16.count)
                            if let groups = volumnOfferRegex
                                .firstMatch(in: html, options: [], range: range)?
                                .groups(testedString: html),
                                let volumnDiscountString = groups.get(at: 0) {
                                let volumnOfferContentRegex = try NSRegularExpression(pattern: "\\[[^\\]]*\\]")
                                let contentRange = NSRange(location: 0, length: volumnDiscountString.utf16.count)
                                if let contentGroups = volumnOfferContentRegex
                                    .firstMatch(in: volumnDiscountString,
                                            options: [], range: contentRange)?
                                    .groups(testedString: volumnDiscountString),
                                    let volumnDiscountContentString = contentGroups.get(at: 0),
                                    let jsonData = volumnDiscountContentString.data(using: .utf8)
                                {
                                    let decoder = JSONDecoder()
                                    let decodedData = (try? decoder.decode([VolumeDiscountResponse].self, from: jsonData)) ?? []
                                    if !decodedData.isEmpty {
                                        volumeDiscounts = decodedData.filter {
                                            $0.quantity != nil && $0.afterDiscountItemPriceDouble != nil
                                        }.map {
                                            let quantity = $0.quantity!
                                            let afterDiscountItemPriceDoule = Double($0.afterDiscountItemPriceDouble!) ?? 0.0
                                            let afterDiscountItemPrice = Int(afterDiscountItemPriceDoule * 100.0)
                                            return VolumeDiscount(quantity: quantity, afterDiscountItemPrice: afterDiscountItemPrice)
                                        }
                                    }
                                }

                            }
                        }

                        return (directDiscount, volumeDiscounts)
                    }

                    return (nil, nil)
                } catch _ {
                    return (nil, nil)
                }
            }
    }

    private func searchItem(epid: String) -> EventLoopFuture<String?> {
        let url = URI(
            scheme: "https",
            host: "api.ebay.com",
            path: "buy/browse/v1/item_summary/search")
        return self.client.get(
            url,
            headers: [
                "Accept": "application/json",
                "X-EBAY-C-MARKETPLACE-ID": "EBAY_US",
                "Authorization": "Bearer \(self.currentToken?.accessToken ?? "")"
        ]) { (request: inout ClientRequest) throws in
            let input = EbaySearchItemInput(epid: epid)
            try request.query.encode(input)
        }.flatMapThrowing { (response: ClientResponse) throws in
            let ebayResponse = try response.content.decode(EbayItemSearchResponse.self)
            guard let summaries = ebayResponse.itemSummaries, !summaries.isEmpty else {
                return nil
            }

            return summaries.first!.itemId
        }
    }

    private func searchLegacyItem(itemID: String) -> EventLoopFuture<String?> {
        let url = URI(
            scheme: "https",
            host: "api.ebay.com",
            path: "buy/browse/v1/item/get_item_by_legacy_id")
        return self.client.get(url,
                               headers: [
                                    "Accept": "application/json",
                                    "X-EBAY-C-MARKETPLACE-ID": "EBAY_US",
                                    "Authorization": "Bearer \(self.currentToken?.accessToken ?? "")"
        ]) { (request: inout ClientRequest) throws in
            let input = EbaySearchLegacyItemInput(legacyItemID: itemID)
            try request.query.encode(input)
        }.map { (response: ClientResponse) in
            do {
                let ebayResponse = try response.content.decode(EbayGetItemResponse.self)
                return ebayResponse.itemId
            } catch let error {
                print("search legacy error", error)
                return nil
            }
        }
    }

    private func searchItem(itemID: String) -> EventLoopFuture<String?> {
        let url = URI(
            scheme: "https",
            host: "api.ebay.com",
            path: "buy/browse/v1/item_summary/search")
        return self.client.get(
            url,
            headers: [
                "Accept": "application/json",
                "X-EBAY-C-MARKETPLACE-ID": "EBAY_US",
                "Authorization": "Bearer \(self.currentToken?.accessToken ?? "")"
        ]) { (request: inout ClientRequest) throws in
            let input = EbaySearchItemInput(q: itemID)
            try request.query.encode(input)
        }.flatMapThrowing { (response: ClientResponse) throws in
            let ebayResponse = try response.content.decode(EbayItemSearchResponse.self)
            guard let summaries = ebayResponse.itemSummaries, !summaries.isEmpty else {
                return nil
            }

            return summaries.first!.itemId
        }
    }

    private func refreshTokenToken() -> EventLoopFuture<Void> {
        if
            self.currentToken != nil,
            let expiryDate = self.tokenExpiryDate,
            Date() < expiryDate
        {
            return self.client.eventLoop.makeSucceededFuture(())
        }

        if let currentCall = self.currentRefreshTokenCall {
            return currentCall
        }

        let url = URI(
            scheme: "https",
            host: "api.ebay.com",
            path: "identity/v1/oauth2/token")
        let credentials = "\(self.ebayAppID):\(self.ebayAppSecret)"
        let encoded = Data(credentials.utf8).base64EncodedString()

        let future = self.client.post(
            url,
            headers: [
                "Content-Type": "application/x-www-form-urlencoded",
                "Authorization": "Basic \(encoded)"
            ]) { (request: inout ClientRequest) throws in
                let form = EbayClientCredentialsForm()
                try request.content.encode(form, as: .urlEncodedForm)
        }.flatMapThrowing { (response: ClientResponse) throws -> Void in
            let token = try response.content.decode(EbayToken.self)
            self.currentToken = token
            self.tokenExpiryDate = Date().addingTimeInterval(TimeInterval(token.expiresIn - 60))
            self.currentRefreshTokenCall = nil
        }

        self.currentRefreshTokenCall = future
        return future
    }
}

struct EbaySearchLegacyItemInput: Content {
    var legacyItemID: String
    
    enum CodingKeys: String, CodingKey {
        case legacyItemID = "legacy_item_id"
    }
}

struct EbaySearchItemInput: Content {
    var q: String?
    var epid: String?
    var filter: String = "buyingOptions:{FIXED_PRICE},itemLocationCountry:US"
}

struct EbayItemSearchResponse: Content {
    var itemSummaries: [EbayItemSummaryResponse]?
}

struct EbayItemSummaryResponse: Content {
    var itemId: String
}

struct EbayClientCredentialsForm: Content {
    var grantType: String = "client_credentials"
    var scope: String = "https://api.ebay.com/oauth/api_scope"

    enum CodingKeys: String, CodingKey {
        case grantType = "grant_type"
        case scope = "scope"
    }
}

struct EbayToken: Content {
    var accessToken: String
    var expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
    }
}

struct EbayGetItemResponse: Content {
    var availableCoupons: [AvailableCoupon]?
    var brand: String?
    var buyingOptions: [String]?
    var categoryId: String?
    var categoryPath: String?
    var color: String?
    var condition: String
    var conditionDescription: String?
    var conditionId: String
    var description: String
    var epid: String?
    var estimatedAvailabilities: [EstimatedAvailability]?
    var gender: String?
    var gtin: String?
    var image: Image
    var inferredEpid: String?
    var itemEndDate: String?
    var itemId: String
    var itemLocation: Address?
    var itemWebUrl: String
    var legacyItemId: String
    var marketingPrice: MarketingPrice?
    var material: String?
    var mpn: String?
    var price: ConvertedAmount
    var quantityLimitPerBuyer: Int?
    var seller: SellerDetail
    var shippingOptions: [ShippingOption]
    var shortDescription: String?
    var size: String?
    var sizeSystem: String?
    var title: String
    var topRatedBuyingExperience: Bool?
    var unitPrice: ConvertedAmount?
    var unitPricingMeasure: String?
}

struct VolumeDiscountResponse: Codable {
    var quantity: Int?
    var discountValue: Double?
    var discountValueStrPercent: String?
    var afterDiscountItemPrice: String?
    var afterDiscountItemPriceWithSymbol: String?
    var afterDiscountItemPricePerUnit: String?
    var afterDiscountItemPricePerUnitWithSymbol: String?
    var afterDiscountItemPriceDouble: String?
    var offerText: String?
    var offerTextAccessibility: String?
    var origItemPriceWithSymbol: String?
    var discountAmountWithSymbol: String?
}

extension EbayGetItemResponse {
    struct ShippingOption: Content {
        var additionalShippingCostPerUnit: ConvertedAmount?
        var cutOffDateUsedForEstimate: String?
        var importCharges: ConvertedAmount?
        var maxEstimatedDeliveryDate: String?
        var minEstimatedDeliveryDate: String?
        var quantityUsedForEstimate: Int?
        var shippingCarrierCode: String?
        var shippingCost: ConvertedAmount
        var shippingCostType: String
        var shippingServiceCode: String
        var type: String
    }

    struct SellerDetail: Content {
        var feedbackPercentage: String
        var feedbackScore: Int
        var username: String
    }

    struct MarketingPrice: Content {
        var discountAmount: ConvertedAmount?
        var discountPercentage: String?
        var originalPrice: ConvertedAmount?
        var priceTreatment: PriceTreatment?
    }

    struct Address: Content {
        var addressLine1: String?
        var addressLine2: String?
        var city: String
        var country: String
        var county: String?
        var postalCode: String?
        var stateOrProvince: String?
    }

    struct Image: Content {
        var height: Int?
        var imageUrl: String
        var width: Int?
    }

    struct Amount: Content {
        var currency: String?
        var value: String?
    }

    struct ConvertedAmount: Content {
        var convertedFromCurrency: String?
        var convertedFromValue: String?
        var currency: String?
        var value: String?
    }

    struct AvailableCoupon: Content {
        var constraint: CouponConstraint?
        var discountAmount: Amount?
        var discountType: DiscountType?
        var message: String?
        var redemptionCode: String?
    }

    struct EstimatedAvailability: Content {
        var availabilityThreshold: Int?
        var estimatedAvailabilityStatus: AvailabilityStatusEnum?
        var estimatedAvailableQuantity: Int?
        var estimatedSoldQuantity: Int?
    }
}

extension EbayGetItemResponse.AvailableCoupon {
    struct CouponConstraint: Content {
        var expirationDate: String?
    }

    enum DiscountType: String, Content {
        case itemPrice = "ITEM_PRICE"
    }
}

extension EbayGetItemResponse.EstimatedAvailability {
    enum AvailabilityStatusEnum: String, Content {
        case inStock = "IN_STOCK"
        case limitedStock = "LIMITED_STOCK"
        case outOfStock = "OUT_OF_STOCK"
    }
}

extension EbayGetItemResponse.MarketingPrice {
    enum PriceTreatment: String, Content {
        case minimumAdvertisedPrice = "MINIMUM_ADVERTISED_PRICE"
        case listPrice = "LIST_PRICE"
        case markDown = "MARKDOWN"
    }
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
