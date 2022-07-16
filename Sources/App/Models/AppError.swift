import Foundation
import Vapor
import CodableCSV

enum AppError: String, Error {
    case acccessTokenExpired
    case refreshTokenExpired
    case confirmPasswordDoesntMatch
    case buyerNotVerified
    case uploadJobNotFound
    case uploadFileNotFound
}

extension AppError: AbortError {
    var reason: String {
        return self.rawValue
    }

    var status: HTTPResponseStatus {
        switch self {
        case .refreshTokenExpired:
            return .unauthorized
        default:
            return .badRequest
        }
    }
}

extension CSVError: AbortError {
    public var reason: String {
        return "\(self)"
    }

    public var status: HTTPResponseStatus {
        return .badRequest
    }
}
