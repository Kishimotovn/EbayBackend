import Fluent

struct CreateBuyers: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(Buyer.schema)
            .id()
            .field("username", .string, .required)
            .field("password_hash", .string, .required)
            .field("email", .string, .required)
            .field("phoneNumber", .string, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .field("deleted_at", .datetime)
            .unique(on: "username", "email")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(Buyer.schema).delete()
    }
}
