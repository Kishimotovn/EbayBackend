import Foundation
import Vapor

struct GetPackingRequestInput: Content {
	var trackingNumber: String
}
