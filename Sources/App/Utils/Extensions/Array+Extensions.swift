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
}
