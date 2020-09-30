//
//  File.swift
//  
//
//  Created by Phan Tran on 18/09/2020.
//

import Foundation
import Vapor

struct SellerFeaturedController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let groupedRoutes = routes.grouped("sellerFeatured")
        
        groupedRoutes.post(use: createItemFeaturedHandler)
        groupedRoutes.get(use: getItemFeaturedHandler)
        groupedRoutes.delete(SellerItemFeatured.parameterPath, use: deleteHandler)
        groupedRoutes.put(SellerItemFeatured.parameterPath, use: updateFeaturedItemHandler)
    }

    private func updateFeaturedItemHandler(request: Request) throws -> EventLoopFuture<SellerItemFeatured> {
        guard let _ = request.application.masterSellerID,
              let sellerItemFeaturedID = request.parameters.get(SellerItemFeatured.parameter, as: SellerItemFeatured.IDValue.self) else {
            throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
        }
        let input = try request.content.decode(UpdateSellerItemFeaturedInput.self)

        return request.sellerItemFeatured
            .find(sellerItemFeaturedID: sellerItemFeaturedID)
            .unwrap(or: Abort(.notFound, reason: "Yêu cầu không hợp lệ"))
            .flatMap { item in
                item.price = input.price
                return request.sellerItemFeatured.save(sellerItemFeatured: item).transform(to: item)
            }
    }

    private func deleteHandler(request: Request) throws -> EventLoopFuture<[SellerItemFeatured]> {
        guard
            let masterSellerID = request.application.masterSellerID,
            let sellerItemFeaturedID = request.parameters.get(SellerItemFeatured.parameter, as: SellerItemFeatured.IDValue.self)
        else {
            throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
        }

        return request.sellerItemFeatured.delete(sellerItemFeaturedID: sellerItemFeaturedID).flatMap {
            return request.sellerItemFeatured.find(sellerID: masterSellerID)
        }
    }

    private func getItemFeaturedHandler(request: Request) throws -> EventLoopFuture<[SellerItemFeatured]> {
        guard let masterSellerID = request.application.masterSellerID else {
            throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
        }

        return request
            .sellers
            .find(id: masterSellerID)
            .unwrap(or: Abort(.notFound, reason: "Yêu cầu không hợp lệ"))
            .flatMap { seller in
                return request.sellerItemFeatured.find(sellerID: seller.id!)
        }
    }

    private func createItemFeaturedHandler(request: Request) throws -> EventLoopFuture<[SellerItemFeatured]> {
        guard let masterSellerID = request.application.masterSellerID else {
            throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
        }
        let input = try request.content.decode(CreateItemFeaturedInput.self)
        let sellerFuture = request.sellers.find(id: masterSellerID)
            .unwrap(or: Abort(.notFound, reason: "Yêu cầu không hợp lệ"))

        let addedItemFutures = input.items
            .map { itemInput in
                return request.items
                .find(itemID: itemInput.itemID)
                .map { (item: Item?) -> Item in
                    if let existingItem = item {
                        return existingItem
                    } else {
                        return Item(itemID: itemInput.itemID)
                    }
                }.flatMap { item -> EventLoopFuture<Item>    in
                    item.name = itemInput.name
                    item.imageURL = itemInput.imageURL
                    item.itemURL = itemInput.itemURL
                    item.shippingPrice = itemInput.shippingPrice
                    item.sellerName = itemInput.sellerName
                    item.sellerFeedbackCount = itemInput.sellerFeedbackCount
                    item.sellerScore = itemInput.sellerScore
                    item.originalPrice = itemInput.originalPrice
                    item.condition = itemInput.condition
                    item.lastKnownAvailability = true
                    return request
                        .items
                        .save(item: item)
                        .transform(to: item)
                }
        }.flatten(on: request.eventLoop)
        
        return sellerFuture
            .and(addedItemFutures)
            .flatMap { seller, items in
                return items.map { item in
                    return seller
                        .$featuredItems
                        .attach(item, method: .ifNotExists, on: request.db) { (pivot) in
                            if let inputItem = input.items.first(where: {
                                $0.itemID == item.itemID
                            }) {
                                pivot.furtherDiscountAmount = inputItem.furtherDiscountAmount
                                pivot.volumeDiscounts = inputItem.volumeDiscounts
                                pivot.furtherDiscountDetected = inputItem.furtherDiscountDetected
                                pivot.itemEndDate = inputItem.itemEndDate
                                pivot.price = inputItem.price
                            }
                    }
                }.flatten(on: request.eventLoop)
                .flatMap {
                    return request.sellerItemFeatured.find(sellerID: seller.id!)
                }
            }
    }
}
