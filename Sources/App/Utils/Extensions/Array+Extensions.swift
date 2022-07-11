//
//  File.swift
//  
//
//  Created by Phan Tran on 10/06/2020.
//

import Foundation

extension Array {
    func get(at index: Int) -> Element? {
        guard index >= 0 && self.count > index else {
            return nil
        }
        return self[index]
    }

    
    func indexed<K: Hashable>(by keyForValue: (Element) throws -> K) throws -> [K: Element] {
        return try self.reduce(into: [K: Element]()) { carry, next in
            let key = try keyForValue(next)
            carry[key] = next
        }
    }

    func grouped<K: Hashable>(by keyForValue: (Element) throws -> K) throws -> [K: [Element]] {
        return try Dictionary.init(grouping: self, by: keyForValue)
    }
}

extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var addedDict = [Element: Bool]()

        return filter {
            addedDict.updateValue(true, forKey: $0) == nil
        }
    }

    mutating func removeDuplicates() {
        self = self.removingDuplicates()
    }
}

extension Sequence {
    func asyncForEach(
        _ operation: (Element) async throws -> Void
    ) async rethrows {
        for element in self {
            try await operation(element)
        }
    }
    
    func asyncMap<T>(
        _ operation: (Element) async throws -> T
    ) async rethrows -> [T] {
        var returns = [T]()
        for element in self {
            let returnValue = try await operation(element)
            returns.append(returnValue)
        }
        return returns
    }
}
