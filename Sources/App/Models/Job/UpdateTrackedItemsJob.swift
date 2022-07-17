import Foundation
import Vapor
import Fluent
import Queues
import SendGrid
import CodableCSV
import NIOCore
import SQLKit

struct UpdateTrackedItemJobPayload: Codable {
    var name: String?
}

struct UpdateTrackedItemsJob: AsyncJob {
    typealias Payload = UpdateTrackedItemJobPayload
    
    func dequeue(_ context: QueueContext, _ payload: Payload) async throws {
        let db = context.application.db
        
        let start = Date()
        
        guard try await TrackedItemUploadJob.query(on: db)
            .filter(\.$jobState == .running)
            .first() == nil
        else {
            return
        }

        guard
            let job = try await TrackedItemUploadJob.query(on: db).filter(\.$jobState == .pending).sort(\.$createdAt, .ascending).first(),
            !job.fileID.isEmpty
        else {
            return
        }
        
        job.jobState = .running
        try await job.save(on: db)

        let fileStorage = AzureStorageRepository(
            client: context.application.client,
            logger: context.application.logger,
            storageName: context.application.azureStorageName ?? "",
            accessKey: context.application.azureStorageKey ?? "")

        let file = try await fileStorage.get(name: job.fileID, folder: "Ebay1991").get()
        guard let buffer = file.body else{
            throw AppError.uploadFileNotFound
        }

        let data = Data(buffer: buffer)

        let reader = try CSVReader(input: data) {
            $0.headerStrategy = .none
            $0.presample = false
            $0.escapingStrategy = .doubleQuote
            $0.delimiters.row = "\r\n"
        }
        
        let dateFormatter = DateFormatter()

        var countByDate: [String: Int] = [:]
        let importID = "csv-\(job.state)-\(Date().toISODateTime())"

        var rows: [(String, Date)] = []

        while let row = try reader.readRow() {
            guard
                let firstColValue = row.first,
                let datetime = self.date(from: firstColValue, using: dateFormatter),
                let trackingNumber = row.get(at: 2)?.trimmingCharacters(in: .whitespacesAndNewlines),
                trackingNumber.count >= 5
            else {
                continue
            }

            let date = datetime.toISODate()
            countByDate[date] = (countByDate[date] ?? 0) + 1

            let currentTrackingNumbers = rows.map(\.0)
            
            if (trackingNumber.contains("\n")) {
                let trackingNumbers = trackingNumber.components(separatedBy: "\n")
                for number in trackingNumbers {
                   if !currentTrackingNumbers.contains(number) {
                       rows.append((number, datetime))
                   }
                }
            } else if !currentTrackingNumbers.contains(trackingNumber) {
                rows.append((trackingNumber, datetime))
            }
        }
        
        print("took", Date().timeIntervalSince(start), "to collect and decode csv")
        
        let items = rows

        let results = try await context.application.db.transaction { transactionDB -> [(TrackedItem, Bool)] in
            let allItemsNumbers = items.map(\.0)
            let trackedItemsRepo = DatabaseTrackedItemRepository(db: transactionDB)
            let existingTrackedItems = try await trackedItemsRepo.find(
                filter: .init(
                    sellerID: job.$seller.id,
                    trackingNumbers: allItemsNumbers
                ),
                on: transactionDB
            ).get()
            let existingItemsNumbers = existingTrackedItems.map(\.trackingNumber)
            let newTrackingNumbers = items.filter { item in
                return existingItemsNumbers.allSatisfy {
                    !$0.hasSuffix(item.0)
                }
            }
            
            let updateResults = existingTrackedItems.compactMap { existingTrackedItem -> (TrackedItem, Bool)? in
                guard let targetUpdatedItem = items.first(where: {
                    existingTrackedItem.trackingNumber.hasSuffix($0.0)
                }) else {
                    return nil
                }

                let trackedItemStateChanged = !existingTrackedItem.stateTrails.contains {
                    $0.state == job.state && $0.updatedAt == targetUpdatedItem.1
                }

                if trackedItemStateChanged {
                    let newTrail = TrackedItem.StateTrail.init(
                        state: job.state,
                        updatedAt: targetUpdatedItem.1,
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

            print("took", Date().timeIntervalSince(start), "to format and delete/recreate tracked items")

            let newTrackedItems = newTrackingNumbers.map { item -> TrackedItem in
                let newTrail = TrackedItem.StateTrail(state: job.state, updatedAt: item.1, importID: importID)
                return TrackedItem(
                    sellerID: job.$seller.id,
                    trackingNumber: item.0,
                    stateTrails: [newTrail],
                    sellerNote: "",
                    importIDs: [importID]
                )
            }
            
            let newChunks = newTrackedItems.chunks(ofCount: 500)

            try await newChunks.asyncForEach { chunk in
                try await chunk.create(on: transactionDB)
            }
            print("took", Date().timeIntervalSince(start), "to create new items")

            return updateResults
        }
        
        try await (context.application.db as? SQLDatabase)?.raw("""
        REFRESH MATERIALIZED VIEW CONCURRENTLY \(raw: BuyerTrackedItemLinkView.schema);
        """).run()

        let stateChangedItems = results.filter(\.1).map(\.0)

        if !stateChangedItems.isEmpty {
            let emailRepo = SendGridEmailRepository(appFrontendURL: context.application.appFrontendURL ?? "", queue: context.queue, db: context.application.db, eventLoop: context.eventLoop)
            try await emailRepo.sendTrackedItemsUpdateEmail(for: stateChangedItems).get()
        }

        job.totals = countByDate.compactMap {
            guard let date = Date(isoDate: $0.key) else { return nil }
            return TrackedItemUploadJob.TotalByDate(
                date: date,
                total: $0.value)
        }
        job.jobState = .finished
        try await job.save(on: db)
        try await fileStorage.delete(name: job.fileID, folder: "Ebay1991").get()
        
        let payload = UpdateTrackedItemJobPayload()
        try await context.queue.dispatch(UpdateTrackedItemsJob.self, payload)
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
    
    func error(_ context: QueueContext, _ error: Error, _ payload: Payload) async throws {
        let db = context.application.db

        guard
            let job = try await TrackedItemUploadJob.query(on: db).filter(\.$jobState == .running).first()
        else {
            return
        }
        
        job.error = "\(error)"
        job.jobState = .error
        try await job.save(on: db)
        
        let payload = UpdateTrackedItemJobPayload()
        try await context.queue.dispatch(UpdateTrackedItemsJob.self, payload)
    }
}
