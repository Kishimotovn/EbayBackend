import Foundation
import Vapor
import Fluent
import Queues
import SendGrid
import CodableCSV
import NIOCore
import SQLKit

struct UpdateTrackedItemJobByLinePayload: Codable {
    var date: String
    var trackingNumber: String
    var sheetName: String?
    var sellerID: Seller.IDValue
    var state: TrackedItem.State
}

struct UpdateTrackedItemByLineJob: AsyncJob {
    typealias Payload = UpdateTrackedItemJobByLinePayload
    
    func dequeue(_ context: QueueContext, _ payload: Payload) async throws {
        let isoDateFormatter = ISO8601DateFormatter()
        isoDateFormatter.formatOptions = .withInternetDateTime

        context.logger.info("Running update by line for tracking number \(payload.trackingNumber) - \(payload.date)")

        let importID = "byLine-\(payload.sheetName ?? "N/A")-\(payload.state)-\(Date().toISODateTime())"
        let trackingNumber = payload.trackingNumber.trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let date = isoDateFormatter.date(from: payload.date),
            trackingNumber.count >= 5
        else {
            return
        }
        
        let trackingNumbers: [String]
        if (trackingNumber.contains("\n")) {
            trackingNumbers = trackingNumber.components(separatedBy: "\n").removingDuplicates()
        } else {
            trackingNumbers = [trackingNumber]
        }
        
        let results = try await context.application.db.transaction { transactionDB -> [(TrackedItem, Bool)] in
            let allItemsNumbers = trackingNumbers
            let trackedItemsRepo = DatabaseTrackedItemRepository(db: transactionDB)
            let existingTrackedItems = try await trackedItemsRepo.find(
                filter: .init(
                    sellerID: payload.sellerID,
                    trackingNumbers: allItemsNumbers
                ),
                on: transactionDB
            ).get()
            let existingItemsNumbers = existingTrackedItems.map(\.trackingNumber)
            let newTrackingNumbers = allItemsNumbers.filter { item in
                return existingItemsNumbers.allSatisfy {
                    !$0.hasSuffix(item)
                }
            }
            
            let updateResults = existingTrackedItems.compactMap { existingTrackedItem -> (TrackedItem, Bool)? in
                let trackedItemStateChanged = !existingTrackedItem.stateTrails.contains {
                    $0.state == payload.state && $0.updatedAt == date
                }

                if trackedItemStateChanged {
                    let newTrail = TrackedItem.StateTrail.init(
                        state: payload.state,
                        updatedAt: date,
                        importID: importID
                    )
                    existingTrackedItem.stateTrails.append(newTrail)
                    existingTrackedItem.importIDs.append(importID)
                }

                return (existingTrackedItem, trackedItemStateChanged)
            }
            
            try await existingTrackedItems.delete(on: transactionDB)
            let newExistingTrackedItems = existingTrackedItems.map { $0.new() }
            
            let chunks = newExistingTrackedItems.chunks(ofCount: 500)

            try await chunks.asyncForEach { chunk in
                try await chunk.create(on: transactionDB)
            }

            let newTrackedItems = newTrackingNumbers.map { trackingNumber -> TrackedItem in
                let newTrail = TrackedItem.StateTrail(state: payload.state, updatedAt: date, importID: importID)
                return TrackedItem(
                    sellerID: payload.sellerID,
                    trackingNumber: trackingNumber,
                    stateTrails: [newTrail],
                    sellerNote: "",
                    importIDs: [importID]
                )
            }
            
            let newChunks = newTrackedItems.chunks(ofCount: 500)

            try await newChunks.asyncForEach { chunk in
                try await chunk.create(on: transactionDB)
            }

            // Run every minute.


            return updateResults
        }

//        let stateChangedItems = results.filter(\.1).map(\.0)
//
//        if !stateChangedItems.isEmpty {
//            let emailRepo = SendGridEmailRepository(appFrontendURL: context.application.appFrontendURL ?? "", queue: context.queue, db: context.application.db, eventLoop: context.eventLoop)
//            try await emailRepo.sendTrackedItemsUpdateEmail(for: stateChangedItems).get()
//        }
    }
    
    func error(_ context: QueueContext, _ error: Error, _ payload: UpdateTrackedItemJobByLinePayload) async throws {
        context.logger.info("Failed to update by line for tracking number \(payload.trackingNumber) \(payload.date), error: \(error.localizedDescription)")
    }

    private func date(from string: String, using dateFormatter: DateFormatter) -> Date? {
        let formats = [
            "yyyy-MM-dd",
            "yyyy-MM-dd' 'HH:mm:ss",
            "MM/dd-HH:mm:ss",
            "MM/dd",
            "M/d",
            "MM/dd/yyyy",
            "M/d/yyyy"
        ]
        
        for i in (0..<formats.count) {
            let targetFormat = formats[i]
            dateFormatter.dateFormat = targetFormat

            if let date = dateFormatter.date(from: string) {
                var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
                if components.year == 2000 {
                    components.year = Calendar.current.component(.year, from: Date())
                }
                if let validDate = Calendar.current.date(from: components) {
                    return validDate
                }
            }
        }
        
        return nil
    }
}



