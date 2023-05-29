import Foundation
import Vapor
import Fluent

struct AddPackingRequestLeftToBuyer: Migration {
	func prepare(on database: Database) -> EventLoopFuture<Void> {
		return database.schema(Buyer.schema)
			.field("packing_request_left", .int, .required, .sql(.default(0)))
			.update()
	}

	func revert(on database: Database) -> EventLoopFuture<Void> {
		return database.schema(Buyer.schema)
			.deleteField("packing_request_left")
			.update()
	}
}
