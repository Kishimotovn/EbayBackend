import Fluent

struct CreateBuyers: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("buyers")
            .id()
            .field("username", .string, .required)
            .field("password_hash", .string, .required)
            .field("email", .string, .required)
            .field("phoneNumber", .string, .required)
            .unique(on: "username")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("buyers").delete()
    }
}
