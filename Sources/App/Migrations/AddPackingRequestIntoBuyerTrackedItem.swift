import Foundation
import Vapor
import Fluent

struct AddPackingRequestIntoBuyerTrackedItem: Migration {
	func prepare(on database: Database) -> EventLoopFuture<Void> {
		return database.schema(BuyerTrackedItem.schema)
			.field("packing_request", .string, .required, .sql(.default("")))
			.update()
	}

	func revert(on database: Database) -> EventLoopFuture<Void> {
		return database.schema(BuyerTrackedItem.schema)
			.deleteField("packing_request")
			.update()
	}
}
