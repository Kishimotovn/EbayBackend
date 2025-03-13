import Foundation
import Vapor
import Fluent

protocol FileStorageRepository {
    func upload(file: File,
                to folder: String) throws -> EventLoopFuture<String>
    func upload(data: Data,
                contentType: String,
                with name: String,
                to folder: String) throws -> EventLoopFuture<String>
    func get(name: String, folder: String) throws -> EventLoopFuture<ClientResponse>
    func delete(name: String, folder: String) throws -> EventLoopFuture<Void>
}

extension AzureStorageRepository {
    static let publicFolderName = "public"
}

struct AzureStorageKey: StorageKey {
    typealias Value = String
}
struct AzureStorageName: StorageKey {
    typealias Value = String
}

extension Application {
    var azureStorageKey: String? {
        get {
            self.storage[AzureStorageKey.self]
        }
        set {
            self.storage[AzureStorageKey.self] = newValue
        }
    }
    var azureStorageName: String? {
        get {
            self.storage[AzureStorageName.self]
        }
        set {
            self.storage[AzureStorageName.self] = newValue
        }
    }
}

struct AzureStorageRepository: FileStorageRepository {
    static let host = "blob.core.windows.net"
//    let request: Request
    let client: Client
    let logger: Logger
    let storageName: String
    let accessKey: String
    let signer: Signer

    init(client: Client, logger: Logger, storageName: String, accessKey: String) {
        self.client = client
        self.logger = logger
        self.storageName = storageName
        self.accessKey = accessKey
        self.signer = Signer(name: self.storageName, key: self.accessKey)
    }

    func upload(file: File, to folder: String) throws -> EventLoopFuture<String> {
        let data = Data.init(buffer: file.data)
        let name = "\(UUID().uuidString)-\(file.filename.replacingOccurrences(of: " ", with: "_"))"
        return try self.upload(data: data,
                               contentType: file.contentType?.description ?? "",
                               with: name,
                               to: folder)
    }

    func upload(data: Data, contentType: String, with name: String, to folder: String) throws -> EventLoopFuture<String> {
        let uri = self.generateURL(from: name, folder: folder.lowercased())
        let headers = try self.generateHeaders(for: .PUT,
                                               uri: uri,
                                               with: data,
                                               contentType: contentType)
        return try self.createFolderIfNeeded(name: folder.lowercased())
            .flatMap { _ -> EventLoopFuture<ClientResponse> in
                self.logger.info("uploading to \(uri.string)")
                self.logger.info("headers: \(headers)")
                return self.client.put(uri, headers: headers) { putRequest in
                    putRequest.body = ByteBuffer.init(data: data)
                }
        }.flatMapThrowing { response in
            if response.status == .created {
                return name
            } else {
                throw Abort(.internalServerError, reason: String(buffer: response.body ?? .init()))
            }
        }
    }

    func get(name: String, folder: String) throws -> EventLoopFuture<ClientResponse> {
        let uri = self.generateURL(from: name, folder: folder.lowercased())
        let headers = try self.generateHeaders(for: .GET,
                                               uri: uri)
        return self.client.get(uri, headers: headers)
    }

    func delete(name: String, folder: String) throws -> EventLoopFuture<Void> {
        let uri = self.generateURL(from: name, folder: folder.lowercased())
        let headers = try self.generateHeaders(for: .DELETE,
                                               uri: uri)
        return self.client.delete(uri, headers: headers).transform(to: ())
    }

    private func createFolderIfNeeded(name: String) throws -> EventLoopFuture<Void> {
        let uri = URI(
            scheme: "https",
            host: "\(self.storageName).\(AzureStorageRepository.host)",
            path: "\(name)",
            query: "restype=container")
        let headers = try self.generateHeaders(for: .PUT,
                                               uri: uri)
        self.logger.info("creating folder: \(uri.string)")
        self.logger.info("headers: \(headers)")
        return self.client.put(uri,
                                       headers: headers)
            .flatMapThrowing { response in
                guard response.status == .created || response.status == .conflict else {
                    throw Abort(.internalServerError, reason: String(buffer: response.body ?? .init()))
                }
        }
    }

    private func generateURL(from fileName: String, folder: String) -> URI {
        return URI(scheme: "https",
                   host: "\(self.storageName).\(AzureStorageRepository.host)",
                   path: "\(folder)/\(fileName)")
    }

    private func generateHeaders(for requestMethod: HTTPMethod,
                                 uri: URI,
                                 with data: Data? = nil,
                                 contentType: String? = nil) throws -> HTTPHeaders {
        var headers: [String: String] = [
            "x-ms-date": self.getDateHeader(),
            "x-ms-version": "2019-07-07"
        ]

        if requestMethod == .PUT {
            headers["x-ms-blob-type"] = "BlockBlob"
        } else if requestMethod == .GET {
            headers["If-Modified-Since"] = ""
            headers["If-None-Match"] = ""
        }

        if let data = data {
            headers["Content-Length"] = "\(data.count)"
        }

        if let contentType = contentType {
            headers["Content-Type"] = contentType
        }

        let authValue = try self.generateAuthorizationValue(for: requestMethod,
                                                            headers: headers,
                                                            uri: uri)
        headers["Authorization"] = authValue

        return HTTPHeaders(headers.map { ($0.key, $0.value) })
    }

    private func getDateHeader() -> String {
        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.init(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        return formatter.string(from:  now)
    }

    private func generateAuthorizationValue(for requestMethod: HTTPMethod,
                                            headers: [String: String],
                                            uri: URI) throws -> String {
        let url = URL(string: uri.string)!
        let signature = try self.signer.signature(method: requestMethod,
                                                  url: url,
                                                  headers: headers)
        return "SharedKey \(self.storageName):\(signature)"
    }
}

extension AzureStorageRepository {
    class Signer {
        let name: String
        let key: String

        init(name: String, key: String) {
            self.name = name
            self.key = key
        }

        func signature(method: HTTPMethod,
                       url: URL,
                       headers: [String: String]) throws -> String {
            var sendingHeaders = headers
            sendingHeaders["Date"] = ""
            let message = signableString(method, url: url, headers: sendingHeaders)
            let decodedData = Data(base64Encoded: key, options: .ignoreUnknownCharacters)
            if let keyData = decodedData, let messageData = message.data(using: .utf8) {
                let hmac = HMAC<SHA256>.authenticationCode(for: messageData, using: .init(data: keyData))
                let hmacData = Data.init(hmac)
                return hmacData.base64EncodedString()
            }
            return ""
        }

        private func signableString(_ method: HTTPMethod,
                                    url: URL,
                                    headers: [String: String]) -> String {
            let comps: [String] = [
                method.string.uppercased(),
                headers["Content-Encoding"] ?? "",
                headers["Content-Language"] ?? "",
                headers["Content-Length"] ?? "",
                headers["Content-Md5"] ?? "",
                headers["Content-Type"] ?? "",
                headers["Date"] ?? "",
                headers["If-Modified-Since"] ?? "",
                headers["If-Match"] ?? "",
                headers["If-None-Match"] ?? "",
                headers["If-Unmodified-Since"] ?? "",
                headers["Range"] ?? "",
                canonicalizedHeaders(headers),
                canonicalizedResource(from: url, accountname: self.name)
            ]

            return comps.joined(separator: "\n")
        }

        private func canonicalizedHeaders(_ headers : [String: String]) -> String {
            return headers.filter {
                return $0.key.hasPrefix("x-ms-")
            }.sorted { lhs, rhs -> Bool in
                return lhs.key < rhs.key
            }.map {
                return "\($0.key.trimmingCharacters(in: .whitespacesAndNewlines)):\($0.value)"
            }.joined(separator: "\n")
        }

        private func canonicalizedResource(from url: URL, accountname: String) -> String {
            var comps = [String]()

            var pathComp = "/\(accountname)"
            pathComp += url.path

            comps.append(pathComp)

            let allQueryParams = (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []).reduce([String: String]()) { carry, queryItem in
                var nextCarry = carry
                if
                    let key = queryItem.name.lowercased().removingPercentEncoding,
                    let value = queryItem.value?.removingPercentEncoding
                {
                    nextCarry[key] = value
                }
                return nextCarry
            }.sorted { lhs, rhs in
                return lhs.key < rhs.key
            }.map {
                return "\($0.key):\($0.value)"
            }

            comps.append(contentsOf: allQueryParams)

            return comps.joined(separator: "\n")
        }
    }
}

struct FileStorageRepositoryFactory: @unchecked Sendable {
    var make: ((Request) -> FileStorageRepository)?
    
    mutating func use(_ make: @escaping ((Request) -> FileStorageRepository)) {
        self.make = make
    }
}

extension Application {
    private struct FileStorageRepositoryKey: StorageKey {
        typealias Value = FileStorageRepositoryFactory
    }
    
    var fileStorages: FileStorageRepositoryFactory {
        get {
            self.storage[FileStorageRepositoryKey.self] ?? .init()
        }
        set {
            self.storage[FileStorageRepositoryKey.self] = newValue
        }
    }
}

extension Request {
    var fileStorages: FileStorageRepository {
        self.application.fileStorages.make!(self)
    }
}
