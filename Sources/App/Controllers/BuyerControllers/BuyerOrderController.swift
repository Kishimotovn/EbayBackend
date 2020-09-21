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

        groupedRoutes.group(BuyerJWTAuthenticator()) { buyerOrNotRoutes in
            buyerOrNotRoutes.get("accessibleWarehouseAddresses", use: getAccessibleWarehouseAddressesHandler)
        }

        let buyerProtectedRoutes = groupedRoutes
            .grouped(BuyerJWTAuthenticator())
            .grouped(Buyer.guardMiddleware())

        // Ware houses:
        buyerProtectedRoutes.post("warehouses", use: createWarehouseAddressHandler)
        buyerProtectedRoutes.post("warehouses", "multiple", use: createWarehouseAddressesHandler)

        // Orders:
        buyerProtectedRoutes.get("active", use: getActiveOrdersHandler)
        buyerProtectedRoutes.get("inactive", use: getInactiveOrdersHandler)

        // Cart Orders:
        buyerProtectedRoutes.delete("cart", OrderItem.parameterPath, use: deleteCartOrderItemHandler)
        buyerProtectedRoutes.put("cart", OrderItem.parameterPath, use: updateCartOrderItemHandler)
        buyerProtectedRoutes.post("addItemToCart", use: addItemToCartHandler)
        buyerProtectedRoutes.post("addFeaturedItemToCart", use: addFeaturedItemToCartHandler)
        buyerProtectedRoutes.post("addItemsToCart", use: addItemsToCartHandler)
        buyerProtectedRoutes.get("cart", use: getCartOrderHandler)
        buyerProtectedRoutes.put("rearrangeOrderItem", use: rearrangeOrderItemHandler)
        buyerProtectedRoutes.put("updateWarehouseAddress", use: updateWarehouseHandler)
        buyerProtectedRoutes.put("updateOrderOption", use: updateOrderOptionHandler)
        buyerProtectedRoutes.put("updateOrderRegistrationTime", use: updateOrderRegistrationTimeHandler)
        buyerProtectedRoutes.put(Order.parameterPath, "acceptPriceChanges", use: acceptPriceChangesHandler)
        buyerProtectedRoutes.put(Order.parameterPath, "denyPriceChanges", use: denyPriceChangesHandler)
    }

    // MARK: - Buyer order's info:
    private func denyPriceChangesHandler(request: Request) throws -> EventLoopFuture<Order> {
        guard let orderID = request.parameters.get(Order.parameter, as: Order.IDValue.self) else {
            throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
        }

        let buyer = try request.auth.require(Buyer.self)
        let buyerID = try buyer.requireID()

        return request
            .orders
            .find(orderID: orderID)
            .unwrap(or: Abort(.badRequest, reason: "Yêu cầu không hợp lệ"))
            .tryFlatMap { order -> EventLoopFuture<Order> in
                guard order.$buyer.id == buyerID else {
                    throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
                }

                guard order.state == .priceChanged else {
                    throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
                }

                return order
                    .$orderItems
                    .load(on: request.db)
                    .transform(to: order)
            }.flatMap { order in
                return order.orderItems.map { orderItem in
                    if let _ = orderItem.updatedPrice {
                        return request.orderItems.delete(orderItem: orderItem)
                    } else {
                        return request.eventLoop.future()
                    }
                }.flatten(on: request.eventLoop)
                .flatMap {
                    return order
                        .$orderItems
                        .load(on: request.db)
                        .transform(to: order)
                }
                .transform(to: order)
        }.flatMap { order in
            if order.orderItems.isEmpty {
                order.state = .failed
                return request
                    .orders
                    .save(order: order)
                    .tryFlatMap {
                        return try request.emails.sendOrderUpdateEmail(for: order)
                    }.transform(to: order)
            } else {
                order.state = .registered
                return request
                    .orders
                    .save(order: order)
                    .tryFlatMap {
                        return try request.emails.sendOrderUpdateEmail(for: order)
                    }.transform(to: order)
            }
        }
    }

    private func acceptPriceChangesHandler(request: Request) throws -> EventLoopFuture<Order> {
        guard let orderID = request.parameters.get(Order.parameter, as: Order.IDValue.self) else {
            throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
        }

        let buyer = try request.auth.require(Buyer.self)
        let buyerID = try buyer.requireID()

        return request
            .orders
            .find(orderID: orderID)
            .unwrap(or: Abort(.badRequest, reason: "Yêu cầu không hợp lệ"))
            .tryFlatMap { order -> EventLoopFuture<Order> in
                guard order.$buyer.id == buyerID else {
                    throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
                }

                guard order.state == .priceChanged else {
                    throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
                }

                return order
                    .$orderItems
                    .load(on: request.db)
                    .transform(to: order)
            }.flatMap { order in
                return order.orderItems.map { orderItem in
                    if let updatedPrice = orderItem.updatedPrice {
                        orderItem.acceptedPrice = updatedPrice
                        orderItem.updatedPrice = nil
                    }
                    return request.orderItems.save(orderItem: orderItem)
                }.flatten(on: request.eventLoop)
                .transform(to: order)
        }.flatMap { order in
            order.state = .registered
            return request
                .orders
                .save(order: order)
                .tryFlatMap {
                    return try request.emails.sendOrderUpdateEmail(for: order)
                }.transform(to: order)
        }
    }

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

    private func createWarehouseAddressesHandler(request: Request) throws -> EventLoopFuture<HTTPResponseStatus> {
        let buyer = try request.auth.require(Buyer.self)
        let input = try request.content.decode(CreateWarehouseAddressesInput.self)

        return input.warehouseAddresses.map { warehouseInput in
            let warehouseAddress = warehouseInput.warehouseAddress()

            return request
               .warehouseAddresses
               .save(warehouseAddress: warehouseAddress)
               .transform(to: warehouseAddress)
               .tryFlatMap { warehouseAddress -> EventLoopFuture<Void> in
                   let buyerWarehouseAddress = try BuyerWarehouseAddress(name: warehouseInput.name,
                                                                         buyerID: buyer.requireID(),
                                                                         warehouseID: warehouseAddress.requireID())
                   return request
                       .buyerWarehouseAddresses
                       .save(buyerWarehouseAddress: buyerWarehouseAddress)
            }
        }.flatten(on: request.eventLoop)
        .transform(to: .ok)
    }

    private func getAccessibleWarehouseAddressesHandler(request: Request) throws -> EventLoopFuture<BuyerAccessibleWarehouseAddresses> {
        let buyerWarehousesFuture: EventLoopFuture<[BuyerWarehouseAddress]>
        if let buyer = try? request.auth.require(Buyer.self) {
            buyerWarehousesFuture = buyer
                .$buyerWarehouseAddresses
                .load(on: request.db)
                .flatMap {
                    return buyer
                        .buyerWarehouseAddresses
                        .map {
                            return request
                                .buyerWarehouseAddresses
                                .find(id: $0.id!)
                                .unwrap(or: Abort(.notFound, reason: "Địa chỉ không hợp lệ"))
                        }.flatten(on: request.eventLoop)
            }
        } else {
            buyerWarehousesFuture = request.eventLoop.makeSucceededFuture([])
        }

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
                                        .unwrap(or: Abort(.notFound, reason: "Địa chỉ không hợp lệ"))
                                }.flatten(on: request.eventLoop)
                        }.map { warehouses in
                            if let buyer = request.auth.get(Buyer.self) {
                                warehouses.forEach {
                                    $0.name = "\($0.name) - \(buyer.username)"
                                }
                            }
                            return warehouses
                        }
                    } else {
                        return request.eventLoop.makeSucceededFuture([])
                    }
                }
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
            throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
        }

        let buyer = try request.auth.require(Buyer.self)
        let buyerID = try buyer.requireID()

        return request.orders
            .getCartOrder(of: buyerID)
            .unwrap(or: Abort(.notFound, reason: "Yêu cầu không hợp lệ"))
            .flatMap { cartOrder -> EventLoopFuture<OrderItem> in
                do {
                    let orderID = try cartOrder.requireID()
                    return request
                        .orderItems
                        .find(orderID: orderID, orderItemID: orderItemID)
                        .unwrap(or: Abort(.notFound, reason: "Yêu cầu không hợp lệ"))
                } catch let error {
                    return request.eventLoop.makeFailedFuture(error)
                }
            }.flatMap { orderItem -> EventLoopFuture<HTTPResponseStatus> in
                return request.orderItems.delete(orderItem: orderItem).transform(to: .ok)
        }
    }

    private func updateCartOrderItemHandler(request: Request) throws -> EventLoopFuture<OrderItem> {
        guard let orderItemID = request.parameters.get(OrderItem.parameter, as: OrderItem.IDValue.self) else {
            throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
        }

        let buyer = try request.auth.require(Buyer.self)
        let buyerID = try buyer.requireID()
        let input = try request.content.decode(UpdateCartOrderItemInput.self)

        if let quantity = input.quantity, quantity <= 0 {
            throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
        }

        return request.orders
            .getCartOrder(of: buyerID)
            .unwrap(or: Abort(.notFound, reason: "Yêu cầu không hợp lệ"))
            .flatMap { cartOrder -> EventLoopFuture<OrderItem> in
                do {
                    let orderID = try cartOrder.requireID()
                    return request
                        .orderItems
                        .find(orderID: orderID, orderItemID: orderItemID)
                        .unwrap(or: Abort(.notFound, reason: "Yêu cầu không hợp lệ"))
                } catch let error {
                    return request.eventLoop.makeFailedFuture(error)
                }
            }.flatMap { orderItem -> EventLoopFuture<OrderItem> in
                if let newQuantity = input.quantity {
                    orderItem.quantity = newQuantity
                }
                if let newDiscountAmount = input.furtherDiscountAmount {
                    orderItem.furtherDiscountAmount = newDiscountAmount
                }
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
            .unwrap(or: Abort(.notFound, reason: "Yêu cầu không hợp lệ"))
            .flatMap { cartOrder -> EventLoopFuture<Order> in
                return cartOrder.$buyer.load(on: request.db)
                    .transform(to: cartOrder)
            .flatMap { cartOrder -> EventLoopFuture<Order> in
                if cartOrder.buyer.verifiedAt == nil {
                    cartOrder.state = .buyerVerificationRequired
                } else {
                    cartOrder.orderRegisteredAt = Date()
                    cartOrder.state = .registered
                }

                return request
                    .orders
                    .save(order: cartOrder)
                    .transform(to: cartOrder)
            }.tryFlatMap { order in
                return try request.emails.sendOrderUpdateEmail(for: order).transform(to: order)
            }
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
                        throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
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
            throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
        }

        return try request
            .orders
            .getCartOrder(of: buyer.requireID())
            .unwrap(or: Abort(.notFound, reason: "Yêu cầu không hợp lệ"))
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
            .unwrap(or: Abort(.notFound, reason: "Yêu cầu không hợp lệ"))
            .flatMap { cartOrder in
                var orderRelevanceInfoFutures: [EventLoopFuture<Void>] = []

                if cartOrder.$warehouseAddress.id != nil {
                    orderRelevanceInfoFutures.append(cartOrder.$warehouseAddress.load(on: request.db))
                }

                if cartOrder.$orderOption.id != nil {
                    orderRelevanceInfoFutures.append(cartOrder.$orderOption.load(on: request.db))
                }

                var itemChanged = false
                for item in cartOrder.orderItems {
                    if let endDate = item.itemEndDate, endDate <= Date() {
                        itemChanged = true
                        orderRelevanceInfoFutures.append(request.orderItems.delete(orderItem: item))
                    }
                }

                return EventLoopFuture.andAllSucceed(
                    orderRelevanceInfoFutures,
                    on: request.eventLoop)
                    .tryFlatMap {
                        if itemChanged {
                            return try request
                                       .orders
                                       .getCartOrder(of: buyer.requireID())
                                       .unwrap(or: Abort(.notFound, reason: "Yêu cầu không hợp lệ"))
                        } else {
                            return request.eventLoop.makeSucceededFuture(cartOrder)
                        }
                    }
            }
    }

    private func rearrangeOrderItemHandler(request: Request) throws -> EventLoopFuture<Order> {
        let input = try request.content.decode(RearrangeItemOrderInput.self)
        let buyer = try request.auth.require(Buyer.self)
        let buyerID = try buyer.requireID()

        return request
            .orders
            .getCartOrder(of: buyerID)
            .unwrap(or: Abort(.notFound, reason: "Yêu cầu không hợp lệ"))
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
                    .unwrap(or: Abort(.notFound, reason: "Yêu cầu không hợp lệ"))
            }
    }

    private func addItemsToCartHandler(request: Request) throws -> EventLoopFuture<Order> {
        let input = try request.content.decode(AddItemsToCartInput.self)
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

        let addedItemsFuture = input.items.map { inputItem in
            return request.items
            .find(itemID: inputItem.itemID)
            .map { (item: Item?) -> Item in
                if let existingItem = item {
                    return existingItem
                } else {
                    return Item(itemID: inputItem.itemID)
                }
            }.flatMap { item -> EventLoopFuture<Item>    in
                item.name = inputItem.name
                item.imageURL = inputItem.imageURL
                item.itemURL = inputItem.itemURL
                item.shippingPrice = inputItem.shippingPrice
                item.sellerName = inputItem.sellerName
                item.sellerFeedbackCount = inputItem.sellerFeedbackCount
                item.sellerScore = inputItem.sellerScore
                item.originalPrice = inputItem.originalPrice
                item.condition = inputItem.condition
                item.lastKnownAvailability = true
                return request
                    .items
                    .save(item: item)
                    .transform(to: item)
            }
        }.flatten(on: request.eventLoop)
        
        return cartOrderFuture
                .and(addedItemsFuture)
                .tryFlatMap { order, items -> EventLoopFuture<Void> in
                    return try items.map { item in
                        return try request
                            .orderItems
                            .find(itemID: item.requireID(),
                                  orderID: order.requireID())
                            .flatMapThrowing { pivot -> OrderItem in
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
                            }.flatMap { pivot -> EventLoopFuture<OrderItem> in
                                return pivot.$item.load(on: request.db).transform(to: pivot)
                            }.flatMap { pivot -> EventLoopFuture<Void> in
                                if let inputItem = input.items.first(where: { return $0.itemID == pivot.item.itemID }) {
                                    pivot.quantity += inputItem.quantity
                                    pivot.itemEndDate = inputItem.itemEndDate
                                    pivot.furtherDiscountAmount = inputItem.furtherDiscountAmount
                                    pivot.furtherDiscountDetected = inputItem.furtherDiscountDetected
                                    pivot.volumeDiscounts = inputItem.volumeDiscounts
                                    pivot.acceptedPrice = inputItem.originalPrice
                                    if let volumeDiscount = inputItem.volumeDiscounts?.first(where: {
                                        $0.quantity == inputItem.quantity
                                    }) {
                                        pivot.acceptedPrice = volumeDiscount.afterDiscountItemPrice
                                    }
                                }
                                return request
                                    .orderItems
                                    .save(orderItem: pivot)
                            }
                    }.flatten(on: request.eventLoop)
                }.flatMap { _ -> EventLoopFuture<Order?> in
                    return request
                        .orders
                        .getCartOrder(of: buyer.id!)
                }.unwrap(or: Abort(.internalServerError, reason: "Lỗi hệ thống"))
    }

    private func addFeaturedItemToCartHandler(request: Request) throws -> EventLoopFuture<Order> {
        let input = try request.content.decode(AddFeaturedItemToCardInput.self)
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

        let featuredItemFuture = request
            .sellerItemFeatured
            .find(sellerItemFeaturedID: input.featuredItemID)
            .unwrap(or: Abort(.badRequest, reason: "Yêu cầu không hợp lệ"))
        
        return cartOrderFuture
        .and(featuredItemFuture)
        .tryFlatMap { order, featuredItem in
            return try request
                .orderItems
                .find(itemID: featuredItem.$item.id,
                      orderID: order.requireID())
                .flatMapThrowing { pivot -> OrderItem in
                    if let existingPivot = pivot {
                        return existingPivot
                    } else {
                        let highestIndex = order.orderItems.sorted { lhs, rhs in
                            return lhs.index > rhs.index
                            }.first?.index ?? -1
                        return try OrderItem(orderID: order.requireID(),
                                             itemID: featuredItem.$item.id,
                                             index: highestIndex + 1,
                                             quantity: 0)
                    }
                }.flatMap { pivot -> EventLoopFuture<Void> in
                    pivot.quantity += 1
                    pivot.itemEndDate = featuredItem.itemEndDate
                    pivot.furtherDiscountAmount = featuredItem.furtherDiscountAmount
                    pivot.furtherDiscountDetected = featuredItem.furtherDiscountDetected
                    pivot.volumeDiscounts = featuredItem.volumeDiscounts
                    pivot.acceptedPrice = featuredItem.item.originalPrice
                    if let volumeDiscount = featuredItem.volumeDiscounts?.first(where: {
                        $0.quantity == pivot.quantity
                    }) {
                        pivot.acceptedPrice = volumeDiscount.afterDiscountItemPrice
                    }
                    return request
                        .orderItems
                        .save(orderItem: pivot)
                }
        }.flatMap { _ -> EventLoopFuture<Order?> in
            return request
                .orders
                .getCartOrder(of: buyer.id!)
        }.unwrap(or: Abort(.internalServerError, reason: "Lỗi hệ thống"))
    }

    private func addItemToCartHandler(request: Request) throws -> EventLoopFuture<Order> {
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
                item.itemURL = input.itemURL
                item.shippingPrice = input.shippingPrice
                item.sellerName = input.sellerName
                item.sellerFeedbackCount = input.sellerFeedbackCount
                item.sellerScore = input.sellerScore
                item.originalPrice = input.originalPrice
                item.condition = input.condition
                item.lastKnownAvailability = true
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
                pivot.itemEndDate = input.itemEndDate
                pivot.furtherDiscountAmount = input.furtherDiscountAmount
                pivot.furtherDiscountDetected = input.furtherDiscountDetected
                pivot.volumeDiscounts = input.volumeDiscounts
                pivot.acceptedPrice = input.originalPrice
                if let volumeDiscount = input.volumeDiscounts?.first(where: {
                    $0.quantity == pivot.quantity
                }) {
                    pivot.acceptedPrice = volumeDiscount.afterDiscountItemPrice
                }
                return request
                    .orderItems
                    .save(orderItem: pivot)
            }.flatMap { _ -> EventLoopFuture<Order?> in
                return request
                    .orders
                    .getCartOrder(of: buyer.id!)
            }.unwrap(or: Abort(.internalServerError, reason: "Lỗi hệ thống"))
    }
}
