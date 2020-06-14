//
//  File.swift
//  
//
//  Created by Phan Tran on 10/06/2020.
//

import Foundation

extension NSTextCheckingResult {
    func groups(testedString: String) -> [String] {
        return (0..<self.numberOfRanges)
            .map { String(testedString[Range(self.range(at: $0), in: testedString)!]) }
    }
}
