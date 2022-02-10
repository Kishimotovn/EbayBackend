import Foundation
import Vapor
import FluentKit

struct GetPaginatedOutput: Content {
    var searchString: String?
    var items: [String: [TrackedItem]]
    var metadata: PageMetadata
}
