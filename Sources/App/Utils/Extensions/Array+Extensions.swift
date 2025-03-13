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

extension Sequence where Element: Sendable {
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

    func asyncCompactMap<T>(
        _ operation: (Element) async throws -> T?
    ) async rethrows -> [T] {
        var returns = [T]()
        for element in self {
            if let returnValue = try await operation(element) {
                returns.append(returnValue)
            }
        }
        return returns
    }

    func concurrentForEach(
        withPriority priority: TaskPriority? = nil,
        _ operation: @Sendable @escaping (Element) async throws -> Void
    ) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for element in self {
                group.addTask(priority: priority) {
                    try await operation(element)
                }
            }

            // Propagate any errors thrown by the group's tasks:
            for try await _ in group {}
        }
    }

    func concurrentMap<T: Sendable>(
        withPriority priority: TaskPriority? = nil,
        _ transform: @Sendable @escaping (Element) async throws -> T
    ) async throws -> [T] {
        let tasks = map { element in
            Task(priority: priority) {
                try await transform(element)
            }
        }

        return try await tasks.asyncMap { task in
            try await task.value
        }
    }
    
    func concurrentCompactMap<T: Sendable>(
        withPriority priority: TaskPriority? = nil,
        _ transform: @Sendable @escaping (Element) async throws -> T?
    ) async throws -> [T] {
        let tasks = map { element in
            Task(priority: priority) {
                try await transform(element)
            }
        }

        return try await tasks.asyncCompactMap { task in
            try await task.value
        }
    }
}

extension Array where Element: Sendable {
    func chunkedConcurrentForEach(
        chunkSize: Int,
        withPriority priority: TaskPriority? = nil,
        _ operation: @Sendable @escaping (Element) async throws -> Void
    ) async throws {
        if self.isEmpty {
            return
        }
        
        let chunk = self.prefix(chunkSize)
        try await chunk.concurrentForEach(withPriority: priority, operation)
       
        if chunk.count < chunkSize {
            return
        }
        
        let nextBatch = Array(self.suffix(from: chunkSize))
        try await nextBatch.chunkedConcurrentForEach(chunkSize: chunkSize, withPriority: priority, operation)
    }

    func chunkedConcurrentMap<T: Sendable>(
        chunkSize: Int,
        withPriority priority: TaskPriority? = nil,
        _ transform: @Sendable @escaping (Element) async throws -> T
    ) async throws -> [T] {
        if self.isEmpty {
            return []
        }

        print("remaining: ", self.count)
        let chunk = self.prefix(chunkSize)
        var chunkResults = try await chunk.concurrentMap(withPriority: priority, transform)

        if chunk.count < chunkSize {
            return chunkResults
        }

        let nextBatch = Array(self.suffix(from: chunkSize))
        let nextBacthResults = try await nextBatch.chunkedConcurrentMap(chunkSize: chunkSize, withPriority: priority, transform)
        
        chunkResults.append(contentsOf: nextBacthResults)
        return chunkResults
    }
    
    func chunkedConcurrentCompactMap<T: Sendable>(
        chunkSize: Int,
        withPriority priority: TaskPriority? = nil,
        _ transform: @Sendable @escaping (Element) async throws -> T?
    ) async throws -> [T] {
        if self.isEmpty {
            return []
        }

        print("remaining: ", self.count)
        let chunk = self.prefix(chunkSize)
        var chunkResults = try await chunk.concurrentCompactMap(withPriority: priority, transform)

        if chunk.count < chunkSize {
            return chunkResults
        }

        let nextBatch = Array(self.suffix(from: chunkSize))
        let nextBacthResults = try await nextBatch.chunkedConcurrentCompactMap(chunkSize: chunkSize, withPriority: priority, transform)
        
        chunkResults.append(contentsOf: nextBacthResults)
        return chunkResults
    }
}
