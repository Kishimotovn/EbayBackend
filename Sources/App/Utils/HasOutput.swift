import Foundation
import Fluent
import Vapor

protocol HasOutput {
    associatedtype Output
    func output() -> Output
}

protocol CanBeInitByID {
    associatedtype IDValue
    init(validID: IDValue)
}

extension Array: HasOutput where Element: HasOutput {
    func output() -> [Element.Output] {
        return self.map { $0.output() }
    }
}

extension ChildrenProperty where To: HasOutput {
    func output() -> [To.Output]? {
        if let value = self.value {
            return value.map { $0.output() }
        } else {
            return nil
        }
    }
}

extension OptionalParentProperty where To: HasOutput, To.Output: CanBeInitByID, To.IDValue == To.Output.IDValue {
    func output() -> To.Output? {
        guard let id = self.id else {
            return nil
        }

        if let value = self.wrappedValue {
            return value.output()
        }
        return To.Output(validID: id)
    }
}

extension ParentProperty where To: HasOutput, To.Output: CanBeInitByID, To.IDValue == To.Output.IDValue {
    func output() -> To.Output {
        if let value = self.value {
            return value.output()
        } else {
            return To.Output(validID: self.id)
        }
    }
}

extension SiblingsProperty where To: HasOutput {
    func output() -> [To.Output]? {
        if let value = self.value {
            return value.map { $0.output() }
        }
        return nil
    }
}

extension EventLoopFuture: HasOutput where Value: HasOutput {
    func output() -> EventLoopFuture<Value.Output> {
        return self.map { $0.output() }
    }
}
