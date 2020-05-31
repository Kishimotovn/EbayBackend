//
//  File.swift
//  
//
//  Created by Phan Tran on 28/05/2020.
//

import Foundation
import Vapor
import Fluent

protocol Parameter {
    static var parameter: String { get }
    static var parameterPath: PathComponent { get }
}

extension Parameter {
    static var parameterPath: PathComponent {
        return .parameter(self.parameter)
    }
}

extension Parameter where Self: Model {
    static var parameter: String {
        let className = String(describing: self).snakeCased()
        return "\(className)_id"
    }
}
