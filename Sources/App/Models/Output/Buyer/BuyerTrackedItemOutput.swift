import Foundation
import Vapor
import Fluent

struct BuyerTrackedItemOutput: Content {
    var id: UUID?
    var note: String
    var createdAt: Date?
    var updatedAt: Date?
    var buyer: Buyer?
    var trackingNumber: String
    var trackedItem: TrackedItem?

    internal init(id: UUID? = nil, note: String, createdAt: Date? = nil, updatedAt: Date? = nil, buyer: Buyer?, trackingNumber: String, trackedItem: TrackedItem? = nil) {
        self.id = id
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.buyer = buyer
        self.trackingNumber = trackingNumber
        
        if let validTrackedItem = trackedItem {
            self.trackedItem = validTrackedItem
        } else {
            self.trackedItem = .init(
                sellerID: nil,
                trackingNumber: trackingNumber,
                stateTrails: [],
                sellerNote: "",
                importIDs: [])
        }
    }
}

extension BuyerTrackedItem {
    func output(with trackedItem: TrackedItem?) -> BuyerTrackedItemOutput {
        .init(
            id: self.id,
            note: self.note,
            createdAt: self.createdAt,
            updatedAt: self.updatedAt,
            buyer: self.$buyer.value,
            trackingNumber: self.trackingNumber,
            trackedItem: trackedItem
        )
    }

    func output(with trackedItems: [TrackedItem]) -> BuyerTrackedItemOutput {
        let trackedItem = trackedItems.first(where: {
            $0.trackingNumber.hasSuffix(self.trackingNumber)
        })
        
        return self.output(with: trackedItem)
    }

    func output(in db: Database) async throws -> BuyerTrackedItemOutput {
        let trackedItems = try await self.$trackedItems.get(on: db)
        return self.output(with: trackedItems.first)
    }
}
