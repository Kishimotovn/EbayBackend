//
//  File.swift
//  
//
//  Created by Phan Tran on 28/05/2020.
//

import Foundation
import Vapor
import Fluent
import FileProvider

struct SellerOrderController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let groupedRoutes = routes.grouped("sellerOrders")

        groupedRoutes.get("active", use: getActiveOrders)
        groupedRoutes.get("waitingForTracking", use: getWaitingForTrackingOrdersHandler)
        groupedRoutes.get("buyerAnalytics", use: getBuyerAnalyticsHandler)

        groupedRoutes.get("itemSubscriptions", use: getItemSubscriptionsHandler)
        groupedRoutes.get("itemSubscriptions", Item.parameterPath, use: refreshItemSubscriptionHandler)
        groupedRoutes.post("itemSubscriptions", use: addItemSubscriptionHandler)
        groupedRoutes.delete("itemSubscriptions", Item.parameterPath, use: deleteItemSubscriptionHandler)
        groupedRoutes.get("itemSubscriptions", "lastFetch", use: getLastJobMonitoringHandler)

        groupedRoutes.get(Order.parameterPath, use: getOrderHandler)
        groupedRoutes.put(Order.parameterPath, "inProgress", use: moveOrderToWaitingForTrackingState)
        groupedRoutes.put(Order.parameterPath, "waitingForTracking", use: moveOrderToWaitingForTrackingState)
        groupedRoutes.put(Order.parameterPath, "delivered", use: moveOrderToDelivered)

        let validatedRoutes = groupedRoutes.grouped(OrderItemIDValidator())
        
        validatedRoutes.put(Order.parameterPath, OrderItem.parameterPath, use: updateOrderItemHandler)
        validatedRoutes.on(.POST, Order.parameterPath, OrderItem.parameterPath, "receipts", body: .collect(maxSize: "1mb"), use: createReceiptHandler)

        validatedRoutes.group(OrderItemReceiptIDValidator()) { validated in
            validated.get(Order.parameterPath, OrderItem.parameterPath, "receipts", OrderItemReceipt.parameterPath, "image", use: getReceiptImage)
            validated.delete(Order.parameterPath, OrderItem.parameterPath, "receipts", OrderItemReceipt.parameterPath, use: deleteReceiptHandler)
            validated.put(Order.parameterPath, OrderItem.parameterPath, "receipts", OrderItemReceipt.parameterPath, use: updateReceiptHandler)
        }

//        let restrictedRoutes = validatedRoutes
//            .grouped(SellerUpdateOrderRestrictor())
    }

    private func refreshItemSubscriptionHandler(request: Request) throws -> EventLoopFuture<Item> {
        guard
            let itemID = request.parameters.get(Item.parameter, as: Item.IDValue.self),
            let masterSellerID = request.application.masterSellerID
        else {
            throw Abort(.badRequest)
        }

        return request.sellerItemSubscriptions
            .find(itemID: itemID, sellerID: masterSellerID)
            .unwrap(or: Abort(.notFound))
            .flatMap { subscription
                in
                let item = subscription.item
                
                return request.ebayAPIs.getItemDetails(ebayItemID: item.itemID)
                    .flatMap { output -> EventLoopFuture<Void> in
                        item.name = output.name
                        item.imageURL = output.imageURL
                        item.itemURL = output.itemURL
                        item.shippingPrice = output.shippingPrice
                        item.sellerName = output.sellerName
                        item.sellerFeedbackCount = output.sellerFeedbackCount
                        item.sellerScore = output.sellerScore
                        item.originalPrice = output.originalPrice
                        item.condition = output.condition
                        item.lastKnownAvailability = output.quantityLeft != "0"
                        return request.items.save(item: item)
                }.transform(to: item)
            }
    }

    private func getLastJobMonitoringHandler(request: Request) throws -> EventLoopFuture<JobMonitoring> {
        return request.jobMonitorings.getLast(jobName: UpdateQuantityJob().name).unwrap(or: Abort(.notFound))
    }

    private func deleteItemSubscriptionHandler(request: Request) throws -> EventLoopFuture<HTTPResponseStatus> {
        guard
            let itemID = request.parameters.get(Item.parameter, as: Item.IDValue.self),
            let masterSellerID = request.application.masterSellerID
        else {
            throw Abort(.badRequest)
        }

        return request.sellerItemSubscriptions
            .find(itemID: itemID, sellerID: masterSellerID)
            .flatMap { (subscription: SellerItemSubscription?) -> EventLoopFuture<Void> in
                if let subscription = subscription {
                    return request.sellerItemSubscriptions.delete(sellerItemSubscription: subscription)
                } else {
                    return request.eventLoop.future()
                }
            }.transform(to: HTTPResponseStatus.ok)
    }

    private func addItemSubscriptionHandler(request: Request) throws -> EventLoopFuture<Item> {
        guard let masterSellerID = request.application.masterSellerID else {
            throw Abort(.badRequest)
        }

        let input = try request.content.decode(CreateItemSubscriptionInput.self)
        
        let sellerFuture = request.sellers.find(id: masterSellerID)
            .unwrap(or: Abort(.notFound))

        let addedItemFuture = request.items
            .find(itemID: input.itemID)
            .map { (item: Item?) -> Item in
                if let existingItem = item {
                    return existingItem
                } else {
                    return Item(itemID: input.itemID)
                }
            }.flatMap { item -> EventLoopFuture<Item>    in
                item.name = input.name
                item.imageURL = input.imageURL
                item.itemURL = input.itemURL
                item.shippingPrice = input.shippingPrice
                item.sellerName = input.sellerName
                item.sellerFeedbackCount = input.sellerFeedbackCount
                item.sellerScore = input.sellerScore
                item.originalPrice = input.originalPrice
                item.condition = input.condition
                item.lastKnownAvailability = input.lastKnownAvailability
                return request
                    .items
                    .save(item: item)
                    .transform(to: item)
            }

        return sellerFuture
            .and(addedItemFuture)
            .flatMap { seller, item in
                return seller.$subscribedItems.attach(item,
                                                      method: .ifNotExists,
                                                      on: request.db)
                .transform(to: item)
        }
    }

    private func getItemSubscriptionsHandler(request: Request) throws -> EventLoopFuture<[Item]> {
        guard let masterSellerID = request.application.masterSellerID else {
            throw Abort(.badRequest)
        }

        return request.sellers.find(id: masterSellerID)
            .unwrap(or: Abort(.notFound))
            .flatMap { seller in
                return seller.$subscribedItems.load(on: request.db)
                    .transform(to: seller.subscribedItems)
        }
    }

    private func moveOrderToDelivered(request: Request) throws -> EventLoopFuture<Order> {
        return try self.moveOrderToState(request: request, state: .delivered)
    }

    private func moveOrderToInProgress(request: Request) throws -> EventLoopFuture<Order> {
        return try self.moveOrderToState(request: request, state: .inProgress)
    }

    private func moveOrderToWaitingForTrackingState(request: Request) throws -> EventLoopFuture<Order> {
        return try self.moveOrderToState(request: request, state: .waitingForTracking)
    }

    private func moveOrderToState(request: Request, state: Order.State) throws -> EventLoopFuture<Order> {
        guard let orderID = request.parameters.get(Order.parameter, as: Order.IDValue.self) else {
            throw Abort(.badRequest)
        }

        return request
            .orders
            .find(orderID: orderID)
            .unwrap(or: Abort(.notFound))
            .flatMap { order in
                order.state = state
                return request.orders.save(order: order).transform(to: order)
        }
    }

    private func updateOrderItemHandler(request: Request) throws -> EventLoopFuture<OrderItem> {
        guard
            let orderID = request.parameters.get(Order.parameter, as: Order.IDValue.self),
            let orderItemID = request.parameters.get(OrderItem.parameter, as: OrderItem.IDValue.self) else {
            throw Abort(.badRequest)
        }

        let input = try request.content.decode(UpdateOrderItemInput.self)

        return request
            .orderItems
            .find(orderID: orderID, orderItemID: orderItemID)
            .unwrap(or: Abort(.notFound))
            .flatMap { orderItem in
                orderItem.isProcessed = input.isProcessed
                return request
                    .orderItems
                    .save(orderItem: orderItem)
                    .transform(to: orderItem)
        }
    }

    private func deleteReceiptHandler(request: Request) throws -> EventLoopFuture<HTTPResponseStatus> {
        guard
            let orderItemReceiptID = request.parameters.get(OrderItemReceipt.parameter, as: OrderItemReceipt.IDValue.self) else {
            throw Abort(.badRequest)
        }

        return request
            .orderItemReceipts
            .find(id: orderItemReceiptID)
            .unwrap(or: Abort(.notFound))
            .tryFlatMap { receipt in
                let workPath = request.application.directory.workingDirectory
                let receiptsFolderName = "Receipts/"
                let receiptName = receipt.imageURL
                
                let path = workPath + receiptsFolderName + receiptName

                let fileManager = FileManager()
                if fileManager.fileExists(atPath: path) && fileManager.isDeletableFile(atPath: path) {
                    try fileManager.removeItem(atPath: path)
                }
                
                return request
                    .orderItemReceipts
                    .delete(orderItemReceipt: receipt)
                    .transform(to: .ok)
        }
    }

    private func getReceiptImage(request: Request) throws -> EventLoopFuture<Response> {
        guard
            let orderItemReceiptID = request.parameters.get(OrderItemReceipt.parameter, as: OrderItemReceipt.IDValue.self) else {
            throw Abort(.badRequest)
        }

        return request
            .orderItemReceipts
            .find(id: orderItemReceiptID)
            .unwrap(or: Abort(.notFound))
            .map { receipt in
                let workPath = request.application.directory.workingDirectory
                let receiptsFolderName = "Receipts/"
                let receiptName = receipt.imageURL
                
                let path = workPath + receiptsFolderName + receiptName
                
                return request.fileio.streamFile(at: path)
        }
    }

    private func getOrderHandler(request: Request) throws -> EventLoopFuture<Order> {
        guard let masterSellerID = request.application.masterSellerID else {
            throw Abort(.badRequest)
        }

        guard let orderID = request.parameters.get(Order.parameter, as: Order.IDValue.self) else {
            throw Abort(.badRequest)
        }

        return request
            .orders
            .getOrder(orderID: orderID, for: masterSellerID)
            .unwrap(or: Abort(.notFound))
    }

    private func getBuyerAnalyticsHandler(request: Request) throws -> EventLoopFuture<[BuyerAnalyticsOutput]> {
        guard let masterSellerID = request.application.masterSellerID else {
            throw Abort(.badRequest)
        }

        return request.sellerAnalytics.buyerAnalytics(sellerID: masterSellerID)
    }

    private func getWaitingForTrackingOrdersHandler(request: Request) throws -> EventLoopFuture<Page<Order>> {
        let pageRequest = try request.query.decode(PageRequest.self)
        guard let sellerID = request.application.masterSellerID else {
            throw Abort(.badRequest)
        }

        return request
            .orders
            .getWaitingForTrackingOrders(sellerID: sellerID, pageRequest: pageRequest)
    }

    private func updateReceiptHandler(request: Request) throws -> EventLoopFuture<OrderItemReceipt> {
        guard let orderItemReceiptID = request.parameters.get(OrderItemReceipt.parameter, as: OrderItem.IDValue.self) else {
            throw Abort(.badRequest)
        }

        let input = try request.content.decode(UpdateOrderItemReceiptInput.self)
        return request
            .orderItemReceipts
            .find(id: orderItemReceiptID)
            .optionalFlatMap { receipt in
                receipt.resolvedQuantity = input.resolvedQuantity
                receipt.trackingNumber = input.trackingNumber

                return request
                    .orderItemReceipts
                    .save(orderItemReceipt: receipt)
                    .transform(to: receipt)
            }
            .unwrap(or: Abort(.notFound))
    }

    private func createReceiptHandler(request: Request) throws -> EventLoopFuture<OrderItemReceipt> {
        guard
            let orderID = request.parameters.get(Order.parameter, as: Order.IDValue.self),
            let orderItemID = request.parameters.get(OrderItem.parameter, as: OrderItem.IDValue.self) else {
            throw Abort(.badRequest)
        }

        let input = try request.content.decode(CreateOrderItemReceiptInput.self)

        let workPath = request.application.directory.workingDirectory
        let receiptsFolderName = "Receipts/"
        let receiptName = "\(orderID)_\(UUID().uuidString).jpg"

        let path = workPath + receiptsFolderName + receiptName

        FileManager().createFile(atPath: path,
                                 contents: input.image,
                                 attributes: nil)

        let receipt = OrderItemReceipt(
            orderItemID: orderItemID,
            imageURL: receiptName,
            trackingNumber: input.trackingNumber,
            resolvedQuantity: input.resolvedQuantity)

        return request
            .orderItemReceipts
            .save(orderItemReceipt: receipt)
            .transform(to: receipt)
    }

    private func getActiveOrders(request: Request) throws -> EventLoopFuture<Page<Order>> {
        let pageRequest = try request.query.decode(PageRequest.self)
        guard let sellerID = request.application.masterSellerID else {
            throw Abort(.badRequest)
        }

        return request
            .orders
            .getActiveOrders(sellerID: sellerID, pageRequest: pageRequest)
    }
}
