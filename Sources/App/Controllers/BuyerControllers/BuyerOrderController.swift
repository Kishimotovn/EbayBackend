//
//  File.swift
//  
//
//  Created by Phan Tran on 25/05/2020.
//

import Foundation
import Vapor
import Fluent

struct BuyerOrderController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let groupedRoutes = routes.grouped("buyerOrders")

        let buyerProtectedRoutes = groupedRoutes
            .grouped(BuyerJWTAuthenticator())
            .grouped(Buyer.guardMiddleware())

        // Ware houses:
        buyerProtectedRoutes.get("accessibleWarehouseAddresses", use: getAccessibleWarehouseAddressesHandler)
        buyerProtectedRoutes.post("warehouses", use: createWarehouseAddressHandler)

        // Orders:
        buyerProtectedRoutes.get("active", use: getActiveOrdersHandler)
        buyerProtectedRoutes.get("inactive", use: getInactiveOrdersHandler)

        // Cart Orders:
        buyerProtectedRoutes.delete("cart", OrderItem.parameterPath, use: deleteCartOrderItemHandler)
        buyerProtectedRoutes.put("cart", OrderItem.parameterPath, use: updateCartOrderItemHandler)
        buyerProtectedRoutes.post("addItemToCart", use: addItemToCardHandler)
        buyerProtectedRoutes.get("cart", use: getCartOrderHandler)
        buyerProtectedRoutes.put("rearrangeOrderItem", use: rearrangeOrderItemHandler)
        buyerProtectedRoutes.put("updateWarehouseAddress", use: updateWarehouseHandler)
        buyerProtectedRoutes.put("updateOrderOption", use: updateOrderOptionHandler)
        buyerProtectedRoutes.put("updateOrderRegistrationTime", use: updateOrderRegistrationTimeHandler)
    }

    // MARK: - Buyer order's info:
    private func getInactiveOrdersHandler(request: Request) throws -> EventLoopFuture<Page<Order>> {
        let pageRequest = try request.query.decode(PageRequest.self)
        let buyer = try request.auth.require(Buyer.self)

        return try request
            .orders
            .getInactiveOrders(buyerID: buyer.requireID(),
                               pageRequest: pageRequest)
    }

    private func getActiveOrdersHandler(request: Request) throws -> EventLoopFuture<Page<Order>> {
        let pageRequest = try request.query.decode(PageRequest.self)
        let buyer = try request.auth.require(Buyer.self)

        return try request
            .orders
            .getActiveOrders(buyerID: buyer.requireID(),
                             pageRequest: pageRequest)
    }

    private func createWarehouseAddressHandler(request: Request) throws -> EventLoopFuture<BuyerWarehouseAddress> {
        let buyer = try request.auth.require(Buyer.self)
        let input = try request.content.decode(CreateWarehouseAddressInput.self)

        let warehouseAddress = input.warehouseAddress()

        return request
            .warehouseAddresses
            .save(warehouseAddress: warehouseAddress)
            .transform(to: warehouseAddress)
            .flatMap { warehouseAddress -> EventLoopFuture<BuyerWarehouseAddress> in
                do {
                    let buyerWarehouseAddress = try BuyerWarehouseAddress(name: input.name,
                                                                          buyerID: buyer.requireID(),
                                                                          warehouseID: warehouseAddress.requireID())
                    return request
                        .buyerWarehouseAddresses
                        .save(buyerWarehouseAddress: buyerWarehouseAddress)
                        .transform(to: buyerWarehouseAddress)
                } catch let error {
                    return request.eventLoop.makeFailedFuture(error)
                }
        }.flatMap { buyerWarehouse in
            return buyerWarehouse
                .$warehouse
                .load(on: request.db)
                .transform(to: buyerWarehouse)
        }
    }

    private func getAccessibleWarehouseAddressesHandler(request: Request) throws -> EventLoopFuture<BuyerAccessibleWarehouseAddresses> {
        let buyer = try request.auth.require(Buyer.self)

        var sellerWarehousesFuture: EventLoopFuture<[SellerWarehouseAddress]> = request.eventLoop.makeSucceededFuture([])
        if let masterSellerID = request.application.masterSellerID {
            sellerWarehousesFuture = request
                .sellers
                .find(id: masterSellerID)
                .flatMap {
                    if let masterSeller = $0 {
                        return masterSeller
                            .$sellerWarehouseAddresses
                            .load(on: request.db)
                            .flatMap {
                                return masterSeller
                                .sellerWarehouseAddresses
                                .map {
                                    return request
                                        .sellerWarehouseAddresses
                                        .find(id: $0.id!)
                                        .unwrap(or: Abort(.notFound))
                                }.flatten(on: request.eventLoop)
                        }
                    } else {
                        return request.eventLoop.makeSucceededFuture([])
                    }
                }
        }

        let buyerWarehousesFuture = buyer
            .$buyerWarehouseAddresses
            .load(on: request.db)
            .flatMap {
                return buyer
                    .buyerWarehouseAddresses
                    .map {
                        return request
                            .buyerWarehouseAddresses
                            .find(id: $0.id!)
                            .unwrap(or: Abort(.notFound))
                    }.flatten(on: request.eventLoop)
        }

        return sellerWarehousesFuture
            .and(buyerWarehousesFuture)
            .map { sellerWarehouseAddresses, buyerWarehouseAddresses in
                return BuyerAccessibleWarehouseAddresses(
                    sellerWarehouseAddresses: sellerWarehouseAddresses,
                    buyerWarehouseAddresses: buyerWarehouseAddresses)
        }
    }

    // MARK: - Cart Order Handlers:
    private func deleteCartOrderItemHandler(request: Request) throws -> EventLoopFuture<HTTPResponseStatus> {
        guard let orderItemID = request.parameters.get(OrderItem.parameter, as: OrderItem.IDValue.self) else {
            throw Abort(.badRequest)
        }

        let buyer = try request.auth.require(Buyer.self)
        let buyerID = try buyer.requireID()

        return request.orders
            .getCartOrder(of: buyerID)
            .unwrap(or: Abort(.notFound))
            .flatMap { cartOrder -> EventLoopFuture<OrderItem> in
                do {
                    let orderID = try cartOrder.requireID()
                    return request
                        .orderItems
                        .find(orderID: orderID, orderItemID: orderItemID)
                        .unwrap(or: Abort(.notFound))
                } catch let error {
                    return request.eventLoop.makeFailedFuture(error)
                }
            }.flatMap { orderItem -> EventLoopFuture<HTTPResponseStatus> in
                return request.orderItems.delete(orderItem: orderItem).transform(to: .ok)
        }
    }

    private func updateCartOrderItemHandler(request: Request) throws -> EventLoopFuture<OrderItem> {
        guard let orderItemID = request.parameters.get(OrderItem.parameter, as: OrderItem.IDValue.self) else {
            throw Abort(.badRequest)
        }

        let buyer = try request.auth.require(Buyer.self)
        let buyerID = try buyer.requireID()
        let input = try request.content.decode(UpdateCartOrderItemInput.self)

        guard input.quantity > 0 else {
            throw Abort(.badRequest)
        }

        return request.orders
            .getCartOrder(of: buyerID)
            .unwrap(or: Abort(.notFound))
            .flatMap { cartOrder -> EventLoopFuture<OrderItem> in
                do {
                    let orderID = try cartOrder.requireID()
                    return request
                        .orderItems
                        .find(orderID: orderID, orderItemID: orderItemID)
                        .unwrap(or: Abort(.notFound))
                } catch let error {
                    return request.eventLoop.makeFailedFuture(error)
                }
            }.flatMap { orderItem -> EventLoopFuture<OrderItem> in
                orderItem.quantity = input.quantity
                return request.orderItems.save(orderItem: orderItem).transform(to: orderItem)
        }.flatMap { orderItem in
            return orderItem.$item
                .load(on: request.db)
                .transform(to: orderItem)
        }
    }

    private func updateOrderRegistrationTimeHandler(request: Request) throws -> EventLoopFuture<Order> {
        let buyer = try request.auth.require(Buyer.self)

        return try request
            .orders
            .getCartOrder(of: buyer.requireID())
            .unwrap(or: Abort(.notFound))
            .flatMap { cartOrder -> EventLoopFuture<Order> in
                cartOrder.orderRegisteredAt = Date()
                cartOrder.state = .registered

                return request
                    .orders
                    .save(order: cartOrder)
                    .transform(to: cartOrder)
        }
    }

    private func updateOrderOptionHandler(request: Request) throws -> EventLoopFuture<Order> {
        let input = try request.content.decode(UpdateOrderOptionInput.self)
        let buyer = try request.auth.require(Buyer.self)

        return try request
            .orders
            .getCartOrder(of: buyer.requireID())
            .unwrap(or: Abort(.notFound))
            .flatMap { cartOrder -> EventLoopFuture<Order> in
                cartOrder.$orderOption.id = input.orderOptionID
                return request
                    .orders
                    .save(order: cartOrder)
                    .flatMap { cartOrder.$orderOption.load(on: request.db) }
                    .transform(to: cartOrder)
            }
    }

    private func updateWarehouseHandler(request: Request) throws -> EventLoopFuture<Order> {
        let input = try request.content.decode(UpdateOrderWarehouseInput.self)
        let buyer = try request.auth.require(Buyer.self)

        let warehouseFuture: EventLoopFuture<WarehouseAddress.IDValue>
        
        if let id = input.existingWarehouseID {
            warehouseFuture = try request
                .warehouseAddresses
                .validateAccess(to: id,
                                for: buyer.requireID())
                .flatMapThrowing { hasAccess in
                    if hasAccess {
                        return id
                    } else {
                        throw Abort(.badRequest)
                    }
            }
        } else if let newWarehouseAddress = input.newWarehouse {
            let warehouseAddress = newWarehouseAddress.warehouseAddress()

            warehouseFuture = request
                .warehouseAddresses
                .save(warehouseAddress: warehouseAddress)
                .transform(to: warehouseAddress)
                .flatMap { savedWarehouseAddress in
                    do {
                        let warehouseAddressID = try savedWarehouseAddress.requireID()
                        let buyerWarehouseAddress = try BuyerWarehouseAddress(
                            name: newWarehouseAddress.name,
                            buyerID: buyer.requireID(),
                            warehouseID: warehouseAddressID)
                        return request
                            .buyerWarehouseAddresses
                            .save(buyerWarehouseAddress: buyerWarehouseAddress)
                            .transform(to: warehouseAddressID)
                    } catch let error {
                        return request.eventLoop.makeFailedFuture(error)
                    }
            }
        } else {
            throw Abort(.badRequest)
        }

        return try request
            .orders
            .getCartOrder(of: buyer.requireID())
            .unwrap(or: Abort(.notFound))
            .and(warehouseFuture)
            .flatMap { cartOrder, warehouseAddress -> EventLoopFuture<Order> in
                cartOrder.$warehouseAddress.id = warehouseAddress
                return request
                    .orders
                    .save(order: cartOrder)
                    .flatMap { cartOrder.$warehouseAddress.load(on: request.db) }
                    .transform(to: cartOrder)
        }
    }

    private func getCartOrderHandler(request: Request) throws -> EventLoopFuture<Order> {
        let buyer = try request.auth.require(Buyer.self)

        return try request
            .orders
            .getCartOrder(of: buyer.requireID())
            .unwrap(or: Abort(.notFound))
            .flatMap { cartOrder in
                var orderRelevanceInfoFutures: [EventLoopFuture<Void>] = []

                if cartOrder.$warehouseAddress.id != nil {
                    orderRelevanceInfoFutures.append(cartOrder.$warehouseAddress.load(on: request.db))
                }

                if cartOrder.$orderOption.id != nil {
                    orderRelevanceInfoFutures.append(cartOrder.$orderOption.load(on: request.db))
                }

                return EventLoopFuture.andAllSucceed(
                    orderRelevanceInfoFutures,
                    on: request.eventLoop)
                .transform(to: cartOrder)
        }
    }

    private func rearrangeOrderItemHandler(request: Request) throws -> EventLoopFuture<Order> {
        let input = try request.content.decode(RearrangeItemOrderInput.self)
        let buyer = try request.auth.require(Buyer.self)
        let buyerID = try buyer.requireID()

        return request
            .orders
            .getCartOrder(of: buyerID)
            .unwrap(or: Abort(.notFound))
            .flatMap { (cartOrder: Order) -> EventLoopFuture<Order> in
                var orderItems = cartOrder.orderItems
                orderItems.sort { lhs, rhs in
                    let lhsIndex = input.newOrder.firstIndex(of: lhs.id!) ?? 0
                    let rhsIndex = input.newOrder.firstIndex(of: rhs.id!) ?? 0
                    return lhsIndex < rhsIndex
                }

                let saveFutures: [EventLoopFuture<Void>] = orderItems.enumerated().map { index, orderItem in
                    orderItem.index = index
                    return request.orderItems.save(orderItem: orderItem)
                }

                return EventLoopFuture
                    .andAllSucceed(saveFutures, on: request.eventLoop)
                    .transform(to: cartOrder)
            }.flatMap { cartOrder in
                return request
                    .orders
                    .getCartOrder(of: buyerID)
                    .unwrap(or: Abort(.notFound))
            }
    }

    private func addItemToCardHandler(request: Request) throws -> EventLoopFuture<Order> {
        let input = try request.content.decode(AddItemToCartInput.self)
        let buyer = try request.auth.require(Buyer.self)

        let cartOrderFuture = try request.orders
            .getCartOrder(of: buyer.requireID())
            .flatMapThrowing { cartOrder -> Order in
                if let existingOrder = cartOrder {
                    return existingOrder
                } else {
                    let newOrder = try Order(buyerID: buyer.requireID())
                    newOrder.$seller.id = request.application.masterSellerID
                    return newOrder
                }
        }.flatMap { order in
            return request.orders
                .save(order: order)
                .transform(to: order)
        }.flatMap { order in
            return order.$orderItems
                .load(on: request.db)
                .transform(to: order)
        }

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
                item.shippingPrice = input.shippingPrice
                item.sellerName = input.sellerName
                item.sellerFeedbackCount = input.sellerFeedbackCount
                item.sellerScore = input.sellerScore
                item.originalPrice = input.originalPrice
                item.condition = input.condition
                return request
                    .items
                    .save(item: item)
                    .transform(to: item)
            }

        return cartOrderFuture
            .and(addedItemFuture)
            .flatMap { order, item -> EventLoopFuture<OrderItem> in
                do {
                    return try request
                        .orderItems
                        .find(itemID: item.requireID(),
                              orderID: order.requireID())
                        .flatMapThrowing { pivot in
                            if let existingPivot = pivot {
                                return existingPivot
                            } else {
                                let highestIndex = order.orderItems.sorted { lhs, rhs in
                                    return lhs.index > rhs.index
                                    }.first?.index ?? -1
                                return try OrderItem(orderID: order.requireID(),
                                                     itemID: item.requireID(),
                                                     index: highestIndex + 1,
                                                     quantity: 0)
                            }
                    }
                } catch let error {
                    return request.eventLoop.makeFailedFuture(error)
                }
            }.flatMap { pivot -> EventLoopFuture<Void> in
                pivot.quantity += input.quantity
                return request
                    .orderItems
                    .save(orderItem: pivot)
            }.flatMap { _ -> EventLoopFuture<Order?> in
                return request
                    .orders
                    .getCartOrder(of: buyer.id!)
            }.unwrap(or: Abort(.internalServerError))
    }
}
