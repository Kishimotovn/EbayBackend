import Foundation
import Vapor
import Fluent
import Queues
import SendGrid

struct UpdateTrackedItemsPayload: Codable {
    struct UpdatingItem: Codable {
        let trackingNumber: String
        let updatedDate: Date
        let state: TrackedItem.State
    }
    var items: [UpdatingItem]
    var masterSellerID: Seller.IDValue
    var importID: String
}

struct UpdateTrackedItemsJob: AsyncJob {
    typealias Payload = UpdateTrackedItemsPayload
    
    func dequeue(_ context: QueueContext, _ payload: Payload) async throws {
        let items = payload.items
        let masterSellerID = payload.masterSellerID
        let importID = payload.importID
        
        let newMonitoring = JobMonitoring(jobName: "upload_\(importID)")
        try await newMonitoring.save(on: context.application.db)
    
        let results = try await context.application.db.transaction { transactionDB -> [(TrackedItem, Bool)] in
            let allItemsNumbers = items.map(\.trackingNumber)
            let trackedItemsRepo = DatabaseTrackedItemRepository(db: transactionDB)
            let existingTrackedItems = try await trackedItemsRepo.find(
                filter: .init(
                    sellerID: masterSellerID,
                    trackingNumbers: allItemsNumbers
                ),
                on: transactionDB
            ).get()
            let existingItemsNumbers = existingTrackedItems.map(\.trackingNumber)
            let newTrackingNumbers = items.filter { item in
                return existingItemsNumbers.allSatisfy {
                    !$0.hasSuffix(item.trackingNumber)
                }
            }
            
            let updateResults = try await existingTrackedItems.asyncCompactMap { existingTrackedItem -> (TrackedItem, Bool)? in
                guard let targetUpdatedItem = items.first(where: {
                    existingTrackedItem.trackingNumber.hasSuffix($0.trackingNumber)
                }) else {
                    return nil
                }

                let trackedItemStateChanged = !existingTrackedItem.stateTrails.contains {
                    $0.state == targetUpdatedItem.state && $0.updatedAt == targetUpdatedItem.updatedDate
                }

                if trackedItemStateChanged {
                    let newTrail = TrackedItem.StateTrail.init(
                        state: targetUpdatedItem.state,
                        updatedAt: targetUpdatedItem.updatedDate,
                        importID: importID
                    )
                    existingTrackedItem.stateTrails.append(newTrail)
                    existingTrackedItem.importIDs.append(importID)
                }

                try await existingTrackedItem.save(on: transactionDB)
                return (existingTrackedItem, trackedItemStateChanged)
            }

            let newTrackedItems = newTrackingNumbers.map { item -> TrackedItem in
                let newTrail = TrackedItem.StateTrail(state: item.state, updatedAt: item.updatedDate, importID: importID)
                return TrackedItem(
                    sellerID: masterSellerID,
                    trackingNumber: item.trackingNumber,
                    stateTrails: [newTrail],
                    sellerNote: "",
                    importIDs: [importID]
                )
            }
            
            try await newTrackedItems.create(on: transactionDB)
            
            return updateResults
        }

        let stateChangedItems = results.filter(\.1).map(\.0)

        if !stateChangedItems.isEmpty {
            let emailRepo = SendGridEmailRepository(appFrontendURL: context.application.appFrontendURL ?? "", queue: context.queue, db: context.application.db, eventLoop: context.eventLoop)
            try await emailRepo.sendTrackedItemsUpdateEmail(for: stateChangedItems).get()
        }
        
        newMonitoring.finishedAt = Date()
        try await newMonitoring.save(on: context.application.db)
    }
    
    func error(_ context: QueueContext, _ error: Error, _ payload: UpdateTrackedItemsPayload) async throws {
        let importID = payload.importID
        let newError = JobMonitoring(jobName: "upload_\(importID)", error: error.localizedDescription)
        try await newError.save(on: context.application.db)
    }
}
