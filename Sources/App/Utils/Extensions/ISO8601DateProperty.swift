import Foundation
import Vapor

@propertyWrapper
public struct ISO8601Date: Codable {
    internal var value: Date

    public var wrappedValue: Date {

        get { return value }
        set { value = newValue }

    }

    public init(date: Date) {
        self.value = date
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dateString = try container.decode(String.self)

        if let date = Date(isoDate: dateString) {
            self.value = date
        } else {
            throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.value.toISODate())
    }
}

@propertyWrapper
public struct OptionalISO8601Date: Codable {
    internal var value: Date?

    public var wrappedValue: Date? {

        get { return value }
        set { value = newValue }

    }

    public init(date: Date?) {
        self.value = date
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.value = nil
        } else {
            let dateString = try container.decode(String.self)

            if let date = Date(isoDate: dateString) {
                self.value = date
            } else {
                throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.value?.toISODate())
    }
}

extension Date {
    init?(isoDate: String) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = .withFullDate
        if let date = formatter.date(from: isoDate) {
            self = date
            return
        }
        return nil
    }

    func toISODate() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = .withFullDate
        return formatter.string(from: self)
    }
}
