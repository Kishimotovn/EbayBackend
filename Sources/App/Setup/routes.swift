import Fluent
import Vapor
import SwiftSoup

func routes(_ app: Application) throws {
    app.get { req in
        return "It works!"
    }

    app.get("hello") { req -> EventLoopFuture<String> in
        return req.eventLoop.future("Hello")
    }

    let apiRoutes = app.grouped("api")
    let versionedRoutes = apiRoutes.grouped("v1")

    try versionedRoutes.register(collection: AuthController())
    try versionedRoutes.register(collection: BuyerOrderController())
    try versionedRoutes.register(collection: OrderMetadataController())
    try versionedRoutes.register(collection: SellerOrderController())
    try versionedRoutes.register(collection: SellerBuyerController())
    try versionedRoutes.register(collection: SellerFeaturedController())
    try versionedRoutes.register(collection: SellerSubcriptionController())
    try versionedRoutes.register(collection: SellerTrackedItemController())
    try versionedRoutes.register(collection: BuyerTrackedItemController())
}
