import Fluent
import Vapor

func routes(_ app: Application) throws {
    app.get { req in
        return "It works!"
    }

    app.get("hello") { req -> String in
        return "Hello, world!"
    }

    let apiRoutes = app.grouped("api")
    let versionedRoutes = apiRoutes.grouped("v1")

    try versionedRoutes.register(collection: AuthController())
    try versionedRoutes.register(collection: BuyerOrderController())
    try versionedRoutes.register(collection: OrderMetadataController())
    try versionedRoutes.register(collection: SellerOrderController())
    try versionedRoutes.register(collection: SellerBuyerController())
    try versionedRoutes.register(collection: SellerFeaturedController())
}
