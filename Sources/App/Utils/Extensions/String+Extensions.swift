//
//  File.swift
//  
//
//  Created by Phan Tran on 28/05/2020.
//

import Foundation

extension String {
    func snakeCased() -> String {
        let acronymPattern = "([A-Z]+)([A-Z][a-z]|[0-9])"
        let normalPattern = "([a-z0-9])([A-Z])"
        return self.processCamalCaseRegex(pattern: acronymPattern)?
            .processCamalCaseRegex(pattern: normalPattern)?.lowercased() ?? self.lowercased()
    }

    fileprivate func processCamalCaseRegex(pattern: String) -> String? {
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: count)
        return regex?.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: "$1_$2")
    }

    func currencyValue() -> Decimal? {
        let numberFormatter = NumberFormatter()
        numberFormatter.allowsFloats = true
        numberFormatter.generatesDecimalNumbers = true
        
        return numberFormatter.number(from: self)?.decimalValue
    }
}
