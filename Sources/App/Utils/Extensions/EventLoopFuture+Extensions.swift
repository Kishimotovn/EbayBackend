//
//  File.swift
//  
//
//  Created by Phan Tran on 10/06/2020.
//

import Foundation
import Vapor

extension EventLoopFuture {
  func tryFlatMap<NewValue>(
    file: StaticString = #file,
    line: UInt = #line,
    _ callback: @escaping (Value) throws -> EventLoopFuture<NewValue>
  ) -> EventLoopFuture<NewValue> {
    return flatMap(file: file, line: line) { result in
      do {
        return try callback(result)
      } catch {
        return self.eventLoop.makeFailedFuture(error, file: file, line: line)
      }
    }
  }
}

extension EventLoopFuture where Value: Collection {
    func first() -> EventLoopFuture<Value.Element?> {
        return self.map { $0.first }
    }
}
