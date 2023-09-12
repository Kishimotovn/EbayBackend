//
//  File.swift
//  
//
//  Created by Phan Tran on 28/05/2020.
//

import Foundation

let trackingNumberRegex = "^[a-zA-Z0-9]{8,}$|^(?=.*[a-zA-Z])[a-zA-Z0-9]{7}$|^[a-zA-Z]\\d{5,7}$"

extension String {
	func removingNonAlphaNumericCharacters() -> String {
		return self.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression)
	}
	
	func requireValidTrackingNumber() -> String? {
		let trimmed = self.removingNonAlphaNumericCharacters()
		
		guard trimmed.isValidTrackingNumber() else {
			return trimmed
		}
		
		return trimmed
	}
	
	func isValidTrackingNumber() -> Bool {
		let regex = try! NSRegularExpression(pattern: trackingNumberRegex)
		let range = NSRange(location: 0, length: self.utf16.count)
		return regex.firstMatch(in: self, options: [], range: range) != nil
	}

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
    
    static func randomCode(length: Int = 16) -> String {
        return NanoID(alphabet: .lowercasedLatinLetters, .numbers, .urlSafe, size: length).new()
    }
}
