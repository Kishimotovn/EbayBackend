import Foundation
import Vapor
import Fluent
import Queues
import SendGrid
import SQLKit

struct PeriodicallyUpdateJob: AsyncScheduledJob {
    func run(context: QueueContext) async throws {
        let now = Date()
        let calendar = Calendar.current
        let minutes = calendar.component(.minute, from: now)

        if minutes % 3 != 0 {
            return
        }

        context.application.logger.info("refresh periodically tracked items")
        try await context.application.db.transaction { transactionDB in
            try await (transactionDB as? SQLDatabase)?.raw("""
            REFRESH MATERIALIZED VIEW CONCURRENTLY \(raw: BuyerTrackedItemLinkView.schema);
            """).run()

            try await (transactionDB as? SQLDatabase)?.raw("""
            REFRESH MATERIALIZED VIEW CONCURRENTLY \(raw: TrackedItemActiveState.schema);
            """).run()
        }
    }
}

extension PeriodicallyUpdateJob: AsyncJob {
    struct Payload: Content {
        var refreshBuyerTrackedItemLinkView: Bool
        var refreshTrackedItemActiveStateView: Bool
    }

    func dequeue(_ context: QueueContext, _ payload: Payload) async throws {
        try await context.application.db.transaction { transactionDB in
            if payload.refreshBuyerTrackedItemLinkView {
                try await (transactionDB as? SQLDatabase)?.raw("""
                REFRESH MATERIALIZED VIEW CONCURRENTLY \(raw: BuyerTrackedItemLinkView.schema);
                """).run()
            }

            if payload.refreshTrackedItemActiveStateView {
                try await (transactionDB as? SQLDatabase)?.raw("""
                REFRESH MATERIALIZED VIEW CONCURRENTLY \(raw: TrackedItemActiveState.schema);
                """).run()
            }
        }
    }
}
