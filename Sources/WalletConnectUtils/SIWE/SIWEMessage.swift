import Foundation

public struct SIWEMessage: Equatable {
    public let domain: String
    public let uri: String // aud
    public let address: String
    public let version: String
    public let nonce: String
    public let chainId: String
    public let iat: String
    public let nbf: String?
    public let exp: String?
    public let statement: String?
    public let requestId: String?
    public let resources: [String]?

    public init(domain: String, uri: String, address: String, version: String, nonce: String, chainId: String, iat: String, nbf: String?, exp: String?, statement: String?, requestId: String?, resources: [String]?) {
        self.domain = domain
        self.uri = uri
        self.address = address
        self.version = version
        self.nonce = nonce
        self.chainId = chainId
        self.iat = iat
        self.nbf = nbf
        self.exp = exp
        self.statement = statement
        self.requestId = requestId
        self.resources = resources
    }

    public func formatted(includeRecapInTheStatement: Bool = false) -> String {

        return """
               \(domain) wants you to sign in with your Ethereum account:
               \(address)
               \(getStatementLine(includeRecapInTheStatement: includeRecapInTheStatement))

               URI: \(uri)
               Version: \(version)
               Chain ID: \(chainId)
               Nonce: \(nonce)
               Issued At: \(iat)\(expLine)\(nbfLine)\(requestIdLine)\(resourcesSection)
               """
    }

    private func getStatementLine(includeRecapInTheStatement: Bool) -> String {
        if includeRecapInTheStatement,
           let recaps = resources?.compactMap { RecapUrn(urn: $0) }
              let decodedRecap = decodeUrnToJson(urn: resource),
           let attValue = decodedRecap["att"] {
            if let statement = statement {
                return "\n\(statement) \(buildRecapStatement(from: attValue))"
            } else {
                return "\n\(buildRecapStatement(from: attValue))"
            }
        } else {
            guard let statement = statement else { return "" }
            return "\n\(statement)"
        }
    }

    

    private func decodeUrnToJson(urn: String) -> [String: [String: [String: [String]]]]? {
        // Check if the URN is in the correct format
        guard urn.starts(with: "urn:recap:") else { return nil }

        // Extract the Base64 encoded JSON part from the URN
        let base64EncodedJson = urn.replacingOccurrences(of: "urn:recap:", with: "")

        // Decode the Base64 encoded JSON
        guard let jsonData = Data(base64Encoded: base64EncodedJson) else { return nil }

        // Deserialize the JSON data into the desired dictionary
        do {
            let decodedDictionary = try JSONDecoder().decode([String: [String: [String: [String]]]].self, from: jsonData)
            return decodedDictionary
        } catch {
            return nil
        }
    }

//    private func buildRecapStatement(from decodedRecap: [String: [String: [String]]]) -> String {
//        RecapStatementBuilder.buildRecapStatement(from: decodedRecap)
//    }

}

private extension SIWEMessage {

    var expLine: String {
        guard  let exp = exp else { return "" }
        return "\nExpiration Time: \(exp)"
    }

    var nbfLine: String {
        guard let nbf = nbf else { return "" }
        return "\nNot Before: \(nbf)"
    }

    var requestIdLine: String {
        guard let requestId = requestId else { return "" }
        return "\nRequest ID: \(requestId)"
    }

    var resourcesSection: String {
        guard let resources = resources else { return "" }
        return resources.reduce("\nResources:") { $0 + "\n- \($1)" }
    }
}
