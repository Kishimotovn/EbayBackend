import Vapor
import Fluent
import Foundation

struct DCController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let groupedRoutes = routes.grouped("DC")
        groupedRoutes.get("buyers", use: getBuyersHandler)
        groupedRoutes.get("buyerTrackedItems", use: getCustomerTrackedItemsHandler)
    }
    
    private func getBuyersHandler(req: Request) async throws -> [BuyerDCOutput] {
        let buyers = try await Buyer.query(on: req.db)
            .withDeleted()
            .all()
        return buyers.map { $0.dcOutput() }
    }
    
    private func getCustomerTrackedItemsHandler(req: Request) async throws -> [BuyerTrackedItemOutput] {
        let currentDate = Date()
        let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: currentDate)
        let buyerTrackedItems = try await BuyerTrackedItem.query(on: req.db)
            .with(\.$buyer)
            .filter(\.$createdAt, .greaterThanOrEqual, threeMonthsAgo)
            .all()
        return buyerTrackedItems.map { $0.outputWithoutTrackedItem()
        }
    }
}
