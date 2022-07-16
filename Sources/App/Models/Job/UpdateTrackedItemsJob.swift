import Foundation
import Vapor
import Fluent
import Queues
import SendGrid
import CodableCSV
import NIOCore

struct UpdateTrackedItemsPayload: Codable {
    var jobID: TrackedItemUploadJob.IDValue
}

struct UpdateTrackedItemsJob: AsyncJob {
    typealias Payload = UpdateTrackedItemsPayload
    
    func dequeue(_ context: QueueContext, _ payload: Payload) async throws {
        let jobID = payload.jobID
        let db = context.application.db
        
        let start = Date()

        guard
            let job = try await TrackedItemUploadJob.query(on: db).filter(\.$id == jobID).first(),
            !job.fileID.isEmpty
        else {
            throw AppError.uploadJobNotFound
        }
        
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
            $0.headerStrategy = .firstLine
            $0.presample = false
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

            if !currentTrackingNumbers.contains(trackingNumber) {
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
        try await job.save(on: db)
        try await fileStorage.delete(name: job.fileID, folder: "Ebay1991").get()
    }

    public func collectFile(
        io: NonBlockingFileIO,
        allocator: ByteBufferAllocator,
        eventLoop: EventLoop,
        at path: String
    ) async throws -> ByteBuffer {
        var data = allocator.buffer(capacity: 0)
        try await self.readFile(io: io, allocator: allocator, eventLoop: eventLoop, at: path) { new in
            var new = new
            data.writeBuffer(&new)
        }
        return data
    }

    
    private func readFile(
        io: NonBlockingFileIO,
        allocator: ByteBufferAllocator,
        eventLoop: EventLoop,
        at path: String,
        chunkSize: Int = NonBlockingFileIO.defaultChunkSize,
        onRead: @escaping (ByteBuffer) async throws -> Void
    ) async throws {
        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: path),
            let fileSize = attributes[.size] as? NSNumber
        else {
           throw Abort(.internalServerError)
        }

        try await self.read(
            io: io,
            allocator: allocator,
            eventLoop: eventLoop,
            path: path,
            fromOffset: 0,
            byteCount:
            fileSize.intValue,
            chunkSize: chunkSize,
            onRead: onRead
        )
    }

    private func read(
        io: NonBlockingFileIO,
        allocator: ByteBufferAllocator,
        eventLoop: EventLoop,
        path: String,
        fromOffset offset: Int64,
        byteCount: Int,
        chunkSize: Int,
        onRead: @escaping (ByteBuffer) async throws -> Void
    ) async throws {
        let fd = try NIOFileHandle(path: path)
        let done = io.readChunked(
            fileHandle: fd,
            fromOffset: offset,
            byteCount: byteCount,
            chunkSize: chunkSize,
            allocator: allocator,
            eventLoop: eventLoop
        ) { chunk in
            let promise = eventLoop.makePromise(of: Void.self)
            promise.completeWithTask {
                try await onRead(chunk)
            }
            return promise.futureResult
        }
        done.whenComplete { _ in
            try? fd.close()
        }
        try await done.get()
    }

    private func date(from string: String, using dateFormatter: DateFormatter) -> Date? {
        let formats = [
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
    
    func error(_ context: QueueContext, _ error: Error, _ payload: UpdateTrackedItemsPayload) async throws {
        print("error", error)
        let jobID = payload.jobID
        let db = context.application.db

        guard
            let job = try await TrackedItemUploadJob.query(on: db).filter(\.$id == jobID).first()
        else {
            return
        }
        
        job.error = error.localizedDescription
        try await job.save(on: db)
        
        let fileName = job.fileName
        var workPath = context.application.directory.workingDirectory
        
        if !workPath.hasSuffix("/") {
            workPath += "/"
        }
        let uploadFolder = ""
        let path = workPath + uploadFolder + fileName

//        let fileManager = FileManager()
//        if fileManager.fileExists(atPath: path) && fileManager.isDeletableFile(atPath: path) {
//            try fileManager.removeItem(atPath: path)
//        }
    }
}
