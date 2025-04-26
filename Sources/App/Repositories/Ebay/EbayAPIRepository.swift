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
    func getItemDetails(seller: String, keyword: String, offset: Int) -> EventLoopFuture<EbayAPIItemListOutput>
    func getItemDetails(itemID: String) -> EventLoopFuture<EbayAPIItemOutput>
    func getItemDetails(ebayItemID: String) -> EventLoopFuture<EbayAPIItemOutput>
    func searchItems(seller: String, keyword: String) -> EventLoopFuture<EbayItemSearchResponse>
    func checkFurtherDiscountFromWebPage(urlString: String) -> EventLoopFuture<Bool>
}

enum EbayError: Error {
    case apiResponseError(code: Int, body: String)
}

class ClientEbayAPIRepository: EbayAPIRepository, @unchecked Sendable {
    let application: Application
    let client: Client
    let ebayAppID: String
    let ebayAppSecret: String
    var tokenExpiryDate: Date?
    var currentToken: EbayToken?
    var currentRefreshTokenCall: EventLoopFuture<Void>?
    lazy var appMetaDatas = {
        return DatabaseAppMetadataRepository(db: self.application.db)
    }()

    init(application: Application, client: Client, ebayAppID: String, ebayAppSecret: String) {
        self.application = application
        self.client = client
        self.ebayAppID = ebayAppID
        self.ebayAppSecret = ebayAppSecret
    }

    func searchItems(seller: String, keyword: String) -> EventLoopFuture<EbayItemSearchResponse> {
        return self.refreshTokenToken()
        .flatMap { () -> EventLoopFuture<ClientResponse> in
            let url = URI(
                scheme: "https",
                host: "api.ebay.com",
                path: "buy/browse/v1/item_summary/search")
            return self.client.get(
                url,
                headers: [
                    "Accept": "application/json",
                    "X-EBAY-C-MARKETPLACE-ID": "EBAY_US",
                    "Authorization": "Bearer \(self.currentToken?.accessToken ?? "")",
                    "Cache-Control": "no-store, must-revalidate"
            ]) { (request: inout ClientRequest) throws in
                let input = EbaySearchItemInput(q: keyword.components(separatedBy: " ").joined(separator: ","), includedSellers: [seller], offset: 0, limit: 100)
                try request.query.encode(input)
            }
        }.flatMapThrowing { (response: ClientResponse) -> EbayItemSearchResponse in
            return try response.content.decode(EbayItemSearchResponse.self)
        }
    }

    func getItemDetails(seller: String, keyword: String, offset: Int) -> EventLoopFuture<EbayAPIItemListOutput> {
        return self.refreshTokenToken()
        .flatMap { () -> EventLoopFuture<ClientResponse> in
            let url = URI(
                scheme: "https",
                host: "api.ebay.com",
                path: "buy/browse/v1/item_summary/search")
            return self.client.get(
                url,
                headers: [
                    "Accept": "application/json",
                    "X-EBAY-C-MARKETPLACE-ID": "EBAY_US",
                    "Authorization": "Bearer \(self.currentToken?.accessToken ?? "")",
                    "Cache-Control": "no-store, must-revalidate"
            ]) { (request: inout ClientRequest) throws in
                let input = EbaySearchItemInput(q: keyword, includedSellers: [seller], offset: offset)
                try request.query.encode(input)
            }
        }.tryFlatMap { (response: ClientResponse) -> EventLoopFuture<EbayAPIItemListOutput> in
            let ebayResponse = try response.content.decode(EbayItemSearchResponse.self)
            guard let summaries = ebayResponse.itemSummaries, !summaries.isEmpty else {
                return self.appMetaDatas.incrementScanCount().map {
                    EbayAPIItemListOutput(
                        items: [],
                        offset: ebayResponse.offset,
                        limit: ebayResponse.limit,
                        total: ebayResponse.total)
                }
            }
            
            let itemIDs = summaries.map{ $0.itemId }
            return self.appMetaDatas.incrementScanCount().flatMap {
                return itemIDs.compactMap { itemID in
                    guard let id = itemID else { return nil }
                    return self.getItemDetails(ebayItemID: id)
                }.flatten(on: self.client.eventLoop)
            }.map { items in
                return EbayAPIItemListOutput(
                    items: items,
                    offset: ebayResponse.offset,
                    limit: ebayResponse.limit,
                    total: ebayResponse.total)
            }
        }
    }

    func getItemDetails(ebayItemID: String) -> EventLoopFuture<EbayAPIItemOutput> {
        return self.refreshTokenToken()
            .flatMap { () -> EventLoopFuture<ClientResponse> in
                let url = URI(
                    scheme: "https",
                    host: "api.ebay.com",
                    path: "buy/browse/v1/item/\(ebayItemID)")
                return self.client.get(
                    url,
                    headers: [
                        "Accept": "application/json",
                        "X-EBAY-C-MARKETPLACE-ID": "EBAY_US",
                        "Authorization": "Bearer \(self.currentToken?.accessToken ?? "")",
                        "Cache-Control": "no-store, must-revalidate"
                ])
            }
        .tryFlatMap { response throws -> EventLoopFuture<EbayAPIItemOutput> in
            guard response.status.code == HTTPResponseStatus.ok.code else {
                throw EbayError.apiResponseError(code: Int(response.status.code),  body: response.body != nil ? String.init(buffer: response.body!) :  "")
            }
            let item = try response.content.decode(EbayGetItemResponse.self, as: .json)
            let shippingPrice = item.shippingOptions.first?.shippingCost?.value?.currencyValue() ?? 0.0

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

            return self
                .appMetaDatas
                .incrementScanCount()
                .flatMap {
                    return furtherDiscountAmount
                }.map { directDiscount, volumeDiscounts in
                    let detected = (directDiscount != nil && directDiscount! > 0) || (volumeDiscounts?.isEmpty == false)
                    return EbayAPIItemOutput(
                        itemID: item.itemId,
                        name: item.title,
                        imageURL: item.image?.imageUrl ?? "",
                        itemURL: item.itemWebUrl,
                        condition: item.condition,
                        shippingPrice: normalizedShippingPrice,
                        originalPrice: normalizedOriginalPrice,
                        sellerName: item.seller?.username,
                        sellerFeedbackCount: item.seller?.feedbackScore,
                        sellerScore: Double(item.seller?.feedbackPercentage ?? ""),
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

    func checkFurtherDiscountFromWebPage(urlString: String) -> EventLoopFuture<Bool> {
        return self.getFurtherDiscountFromWebPage(urlString: urlString, from: 0).map {
            return $0.1 != nil || $0.0 != nil
        }
    }

    private func getFurtherDiscountFromWebPage(urlString: String, from price: Int) -> EventLoopFuture<(Int?, [VolumeDiscount]?)> {
        let uri = URI(string: urlString)

        return self.client.get(uri)
            .map { response -> (Int?, [VolumeDiscount]?) in
//                self.application.logger.info("Got response for \(urlString)")
                do {
                    if let body = response.body {
                        let html = String(buffer: body)
                        let doc: Document = try SwiftSoup.parse(html)
//                        self.application.logger.info("parsed \(urlString)")
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
                "Authorization": "Bearer \(self.currentToken?.accessToken ?? "")",
                "Cache-Control": "no-store, must-revalidate"
        ]) { (request: inout ClientRequest) throws in
            let input = EbaySearchItemInput(epid: epid, excludedSellers: self.application.masterSellerAvoidedSellers)
            try request.query.encode(input)
        }.tryFlatMap { (response: ClientResponse) throws in
            let ebayResponse = try response.content.decode(EbayItemSearchResponse.self)
            guard let summaries = ebayResponse.itemSummaries, !summaries.isEmpty else {
                return self.appMetaDatas.incrementScanCount().transform(to: nil)
            }

            return self.appMetaDatas.incrementScanCount().transform(to: summaries.first!.itemId)
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
                                    "Authorization": "Bearer \(self.currentToken?.accessToken ?? "")",
                                    "Cache-Control": "no-store, must-revalidate"
        ]) { (request: inout ClientRequest) throws in
            let input = EbaySearchLegacyItemInput(legacyItemID: itemID)
            try request.query.encode(input)
        }.flatMap { (response: ClientResponse) in
            do {
                let ebayResponse = try response.content.decode(EbayGetItemResponse.self)
                if self.application.masterSellerAvoidedSellers?.contains(ebayResponse.seller?.username ?? "") == true {
                    return self.appMetaDatas.incrementScanCount().transform(to: nil)
                } else {
                    return self.appMetaDatas.incrementScanCount().transform(to: ebayResponse.itemId)
                }
            } catch let error {
                print("search legacy error", error)
                return self.appMetaDatas.incrementScanCount().transform(to: nil)
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
                "Authorization": "Bearer \(self.currentToken?.accessToken ?? "")",
                "Cache-Control": "no-store, must-revalidate"
        ]) { (request: inout ClientRequest) throws in
            let input = EbaySearchItemInput(q: itemID, excludedSellers: self.application.masterSellerAvoidedSellers)
            try request.query.encode(input)
        }.tryFlatMap { (response: ClientResponse) throws in
            let ebayResponse = try response.content.decode(EbayItemSearchResponse.self)
            guard let summaries = ebayResponse.itemSummaries, !summaries.isEmpty else {
                return self.appMetaDatas.incrementScanCount().transform(to: nil)
            }

            return self.appMetaDatas.incrementScanCount().transform(to: summaries.first!.itemId)
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
        let ids = self.ebayAppID.components(separatedBy: ",")
        let secrets = self.ebayAppSecret.components(separatedBy: ",")
        if self.application.secretIndex >= ids.count {
            self.application.secretIndex = 0
        }
        
        let choosenID = ids.get(at: self.application.secretIndex) ?? ""
        let choosenSecret = secrets.get(at: self.application.secretIndex) ?? ""
        
        let credentials = "\(choosenID):\(choosenSecret)"
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
            self.tokenExpiryDate = Date().addingTimeInterval(60)
            self.currentRefreshTokenCall = nil
            self.application.secretIndex += 1
        }

        self.currentRefreshTokenCall = future
        return future
    }
}

// fix deployment
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
    var offset: String?
    var limit: Int = 10

    init(q: String? = nil,
         epid: String? = nil,
         excludedSellers: [String]? = nil,
         includedSellers: [String]? = nil,
         offset: Int? = nil,
         limit: Int = 10) {
        self.q = q
        self.epid = epid
        var filters = [
            "buyingOptions:{FIXED_PRICE}",
            "itemLocationCountry:US"
        ]
        if let sellers = excludedSellers, !sellers.isEmpty {
            filters.append("excludeSellers:{\(sellers.joined(separator: "|"))}")
        }
        if let sellers = includedSellers, !sellers.isEmpty {
            filters.append("sellers:{\(sellers.joined(separator: "|"))}")
        }
        self.filter = filters.joined(separator: ",")
        if let offset = offset {
            self.offset = "\(offset)"
        }
        self.limit = limit
    }
}

struct EbayItemSearchResponse: Content {
    var itemSummaries: [EbayItemSummaryResponse]?
    var offset: Int
    var limit: Int
    var total: Int
}

extension EbayItemSearchResponse: Equatable {
    public static func ==(lhs: EbayItemSearchResponse, rhs: EbayItemSearchResponse) -> Bool {
        return lhs.itemSummaries == rhs.itemSummaries
            && lhs.offset == rhs.offset
            && lhs.limit == rhs.limit
            && lhs.total == rhs.total
    }
}

struct EbayItemSummaryResponse: Content, Sendable {
    var itemId: String?
    var title: String?
    var image: EbayGetItemResponse.Image?
    var condition: String?
    var itemWebUrl: String?
    var price: EbayGetItemResponse.ConvertedAmount?
    var seller: EbayGetItemResponse.SellerDetail?
    var shippingOptions: [EbayGetItemResponse.ShippingOption]?
    var marketingPrice: EbayGetItemResponse.MarketingPrice?
    

    var safeItemId: String {
        return self.itemId ?? UUID().uuidString
    }

    var safeTitle: String {
        return self.title ?? "N/A"
    }

    var safeWebURL: String {
        return self.itemWebUrl ?? "N/A URL"
    }
}

import DeepDiff

extension EbayItemSummaryResponse: DiffAware {
    typealias DiffId = String

    var diffId: String {
        return self.itemId ?? UUID().uuidString
    }

    static func compareContent(_ a: EbayItemSummaryResponse, _ b: EbayItemSummaryResponse) -> Bool {
        return a.condition == b.condition
            && a.title == b.title
            && a.itemWebUrl == b.itemWebUrl
            && a.price == b.price
            && a.marketingPrice == b.marketingPrice
    }
}

extension EbayItemSummaryResponse: Equatable {
    public static func ==(lhs: EbayItemSummaryResponse, rhs: EbayItemSummaryResponse) -> Bool {
        return lhs.itemId == rhs.itemId
            && lhs.price == rhs.price
            && lhs.marketingPrice == rhs.marketingPrice
            && lhs.title == rhs.title
    }
}

extension EbayGetItemResponse.MarketingPrice: Equatable {
    public static func ==(lhs: EbayGetItemResponse.MarketingPrice, rhs: EbayGetItemResponse.MarketingPrice) -> Bool {
        return lhs.discountAmount == rhs.discountAmount
            && lhs.discountPercentage == rhs.discountPercentage
            && lhs.originalPrice == rhs.originalPrice
    }
}

extension EbayGetItemResponse.ConvertedAmount: Equatable {
    public static func ==(lhs: EbayGetItemResponse.ConvertedAmount, rhs: EbayGetItemResponse.ConvertedAmount) -> Bool {
        return lhs.convertedFromCurrency == rhs.convertedFromCurrency
            && lhs.convertedFromValue == rhs.convertedFromValue
            && lhs.value == rhs.value
            && lhs.currency == rhs.currency
    }
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
    var image: Image?
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
    var seller: SellerDetail?
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
        var shippingCost: ConvertedAmount?
        var shippingCostType: String?
        var shippingServiceCode: String?
        var type: String?
    }

    struct SellerDetail: Content {
        var feedbackPercentage: String?
        var feedbackScore: Int?
        var username: String?
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
        var city: String?
        var country: String?
        var county: String?
        var postalCode: String?
        var stateOrProvince: String?
    }

    struct Image: Content {
        var height: Int?
        var imageUrl: String?
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

struct EbayAPIRepositoryFactory: @unchecked Sendable {
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
