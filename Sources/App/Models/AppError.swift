import Foundation
import Vapor

enum AppError: String, Error {
    case acccessTokenExpired
    case refreshTokenExpired
    case confirmPasswordDoesntMatch
    case buyerNotVerified
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
