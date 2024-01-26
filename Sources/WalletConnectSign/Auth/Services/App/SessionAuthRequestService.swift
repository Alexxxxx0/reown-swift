import Foundation

actor SessionAuthRequestService {
    enum Errors: Error {
        case invalidChain
    }
    private let networkingInteractor: NetworkInteracting
    private let appMetadata: AppMetadata
    private let kms: KeyManagementService
    private let logger: ConsoleLogging
    private let iatProvader: IATProvider

    init(networkingInteractor: NetworkInteracting,
         kms: KeyManagementService,
         appMetadata: AppMetadata,
         logger: ConsoleLogging,
         iatProvader: IATProvider) {
        self.networkingInteractor = networkingInteractor
        self.kms = kms
        self.appMetadata = appMetadata
        self.logger = logger
        self.iatProvader = iatProvader
    }

    func request(params: AuthRequestParams, topic: String) async throws {
        var params = params
        let pubKey = try kms.createX25519KeyPair()
        let responseTopic = pubKey.rawRepresentation.sha256().toHexString()
        let protocolMethod = SessionAuthenticatedProtocolMethod()
        guard let chainNamespace = Blockchain(params.chains.first!)?.namespace,
              chainNamespace == "eip155"
        else {
            throw Errors.invalidChain
        }
        if let methods = params.methods,
           !methods.isEmpty {
            let namespaceRecap = try createNamespaceRecap(methods: methods)
            params.addResource(resource: namespaceRecap)
        }
        let requester = Participant(publicKey: pubKey.hexRepresentation, metadata: appMetadata)
        let payload = AuthPayload(requestParams: params, iat: iatProvader.iat)
        let sessionAuthenticateRequestParams = SessionAuthenticateRequestParams(requester: requester, authPayload: payload)
        let request = RPCRequest(method: protocolMethod.method, params: sessionAuthenticateRequestParams)
        try kms.setPublicKey(publicKey: pubKey, for: responseTopic)
        logger.debug("AppRequestService: Subscribibg for response topic: \(responseTopic)")
        try await networkingInteractor.request(request, topic: topic, protocolMethod: protocolMethod)
        try await networkingInteractor.subscribe(topic: responseTopic)
    }

    private func createNamespaceRecap(methods: [String]) throws -> String {
        try AuthenticatedSessionRecapFactory.createNamespaceRecap(methods: methods)
    }
}
