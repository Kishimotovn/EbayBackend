import Fluent
import FluentPostgresDriver
import Vapor

// configures your application
public func configure(_ app: Application) throws {
    // setup repositories:
    try setupRepositories(app: app)

    // register routes
    try routes(app)

    // configure middlewares
    try middlewares(app: app)

    try redis(app: app)
    try jobs(app: app)

    // configure databases
    try databases(app: app)

    // run migrations
    try migrate(app: app)

    // lifeCycleHandlers
    try lifecycleHandlers(app: app)
}
