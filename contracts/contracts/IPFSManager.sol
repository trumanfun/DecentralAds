// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IAdsManager.sol";
import "./interfaces/IIPFSManager.sol";

/**
 * @title IPFSManager
 * @author Andrea Tedesco (@andreatedesco).
 * @dev Manages IPFS interactions for creating NFT and contract metadata.
 */
contract IPFSManager is FunctionsClient, Ownable, IIPFSManager {
    using FunctionsRequest for FunctionsRequest.Request;

    // =============================================================
    //                           STATE VARIABLES
    // =============================================================

    // The AdsManager contract to interact with.
    IAdsManager public adsManager;

    // Subscription ID for Chainlink Functions.
    uint64 public subscriptionId = 1515;

    // Encrypted secrets for secure data transmission.
    bytes public encryptedSecretsUrls =
        hex"1e9ce0fe8dc86ffbb0e3511f190d8f7703f26b8a425447b37518e52a69f30ee69395d5d5613761ee019fa13949aea7cd6ca33c7e784895e7229642c52f556297fe4b467dc2014656d4642a7d358fc50735cd038d22aa01b56b3cd1ab3f40c1e472a19ba51d9727caee09f1ff7000586f589205b8eb9d27788488253e5f740770d54ccb9443a8c78b6143c4fd917bbf161a";
    
    // The router address for Chainlink requests.
    address public router = 0xA9d587a00A31A52Ed70D6026794a8FC5E2F5dCb0;

    // Donation ID for Chainlink requests.
    bytes32 public donId =
        0x66756e2d6176616c616e6368652d66756a692d31000000000000000000000000;

    // Gas limit for Chainlink requests.
    uint32 public gasLimit = 300000;

    // Mapping to store errors for each request.
    mapping(bytes32 => bytes) public errors;

    // JavaScript source code for NFT creation.
    string private _nftCreationSource =
        "const name = args[0];"
        "const description = args[1];"
        "const image = args[2];"
        "const external_url = args[3];"
        "const width = args[4];"
        "const height = args[5];"
        "const price = parseFloat(args[6]) / Math.pow(10, 18);"
        "const lottery = args.length > 7;"
        "const jsonData = {"
        "  pinataContent: {"
        "    name: name,"
        "    description: description,"
        "    external_url: external_url,"
        "    image: image,"
        "    animation_url: `https://www.onchainconsole.com/preview.html?image=${image}&width=${width}&height=${height}&isLottery=${lottery}`,"
        "    attributes: [{ trait_type: 'Width (cm)', value: `${width}` }, { trait_type: 'Height (cm)', value: `${height}` }, { trait_type: !lottery ? 'Mint Price (USD)' : 'Ticket Price (USD)', value: `${price}` }, !lottery ? {} : {trait_type: 'Ticket Amount', value: args[7]}]"
        "  }"
        "};"
        "const apiResponse = await Functions.makeHttpRequest({"
        "  url: 'https://api.pinata.cloud/pinning/pinJSONToIPFS',"
        "  method: 'POST',"
        "  headers: {"
        "    'Content-Type': 'application/json',"
        "    'Accept': 'application/json',"
        "    'Authorization': `Bearer ${secrets.pinataJWT}`"
        "  },"
        "  data: jsonData"
        "});"
        "if (apiResponse.error) {"
        "  throw new Error(`message: ${apiResponse.message} code: ${apiResponse.code} response: ${JSON.stringify(apiResponse.response)}`);"
        "}"
        "return Functions.encodeString(`https://ipfs.io/ipfs/${apiResponse.data.IpfsHash}`);";

    // JavaScript source code for contract metadata creation.
    string private _contractCreationSource =
        "const name = args[0];"
        "const description = args[1];"
        "const image = args[2];"
        "const banner = args[3];"
        "const external_link = args[4];"
        "const jsonData = {"
        "  pinataContent: {"
        "    name: name,"
        "    description: description,"
        "    external_link: external_link,"
        "    image: image,"
        "    banner: banner"
        "  }"
        "};"
        "const apiResponse = await Functions.makeHttpRequest({"
        "  url: 'https://api.pinata.cloud/pinning/pinJSONToIPFS',"
        "  method: 'POST',"
        "  headers: {"
        "    'Content-Type': 'application/json',"
        "    'Accept': 'application/json',"
        "    'Authorization': `Bearer ${secrets.pinataJWT}`"
        "  },"
        "  data: jsonData"
        "});"
        "if (apiResponse.error) {"
        "  throw new Error(`message: ${apiResponse.message} code: ${apiResponse.code} response: ${JSON.stringify(apiResponse.response)}`);"
        "}"
        "return Functions.encodeString(`https://ipfs.io/ipfs/${apiResponse.data.IpfsHash}`);";

    // =============================================================
    //                               EVENTS
    // =============================================================

    // Event emitted on successful response from IPFS.
    event Response(bytes32 requestId, string ipfsUri, bytes errors);

    // =============================================================
    //                               ERRORS
    // =============================================================

    // Error for unauthorized sender.
    error UnauthorizedSender();

    // =============================================================
    //                          CONSTRUCTOR
    // =============================================================

    /**
     * @dev Constructor that sets the router address and initializes FunctionsClient.
     */
    constructor() FunctionsClient(router) Ownable(_msgSender()) {}

    // =============================================================
    //                         PUBLIC FUNCTIONS
    // =============================================================

    /**
     * @dev Creates metadata (NFT or contract) based on the provided arguments.
     * @param contractOrToken Boolean indicating whether to update contract or NFT source.
     * @param args Array of string arguments for metadata creation.
     * @return requestId The ID of the Chainlink Functions request.
     */
    function createMetadata(
        bool contractOrToken,
        string[] memory args
    ) public override returns (bytes32) {
        // Ensures only the AdsManager contract can create metadata.
        if (_msgSender() != address(adsManager)) revert UnauthorizedSender();

        // Initializes the FunctionsRequest with the appropriate source code.
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(
            contractOrToken ? _contractCreationSource : _nftCreationSource
        );
        req.addSecretsReference(encryptedSecretsUrls);
        req.setArgs(args);

        // Sends the request and obtains the Chainlink Functions request ID.
        bytes32 requestId = _sendRequest(
            req.encodeCBOR(),
            subscriptionId,
            gasLimit,
            donId
        );

        return requestId;
    }

    // =============================================================
    //                         INTERNAL FUNCTIONS
    // =============================================================

    /**
     * @notice Callback function for fulfilling a request.
     * @param requestId The ID of the request to fulfill.
     * @param response The HTTP response data.
     * @param err Any errors from the Functions request.
     */
    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        // Stores the errors for the request.
        errors[requestId] = err;
        // Converts the response bytes to a string (IPFS URI).
        string memory ipfsUri = string(response);
        // Calls the AdsManager to set the IPFS CID for the request.
        adsManager.setIpfsCID(requestId, ipfsUri);
        // Emits the Response event.
        emit Response(requestId, ipfsUri, err);
    }

    // =============================================================
    //                         OWNER FUNCTIONS
    // =============================================================

    /**
     * @dev Updates the address of the AdsManager contract.
     * @param adsManager_ The new address of the AdsManager contract.
     */
    function updateAdsManager(address adsManager_) external onlyOwner {
        adsManager = IAdsManager(adsManager_);
    }

    /**
     * @dev Updates the subscription ID for Chainlink Functions.
     * @param subscriptionId_ The new subscription ID.
     */
    function updateSubscriptionId(uint64 subscriptionId_) external onlyOwner {
        subscriptionId = subscriptionId_;
    }

    /**
     * @dev Updates the encrypted secrets for secure data transmission.
     * @param encryptedSecretsUrls_ The new encrypted secrets.
     */
    function updateEncryptedSecretsUrls(
        bytes memory encryptedSecretsUrls_
    ) external onlyOwner {
        encryptedSecretsUrls = encryptedSecretsUrls_;
    }

    /**
     * @dev Updates the router address for Chainlink requests.
     * @param router_ The new router address.
     */
    function updateRouter(address router_) external onlyOwner {
        router = router_;
    }

    /**
     * @dev Updates the donation ID for Chainlink requests.
     * @param donId_ The new donation ID.
     */
    function updateDonId(bytes32 donId_) external onlyOwner {
        donId = donId_;
    }

    /**
     * @dev Updates the gas limit for Chainlink requests.
     * @param gasLimit_ The new gas limit.
     */
    function updateGasLimit(uint32 gasLimit_) external onlyOwner {
        gasLimit = gasLimit_;
    }

    /**
     * @dev Updates the source code for metadata creation.
     * @param contractOrToken Boolean indicating whether to update contract or NFT source.
     * @param source_ The new source code.
     */
    function updateSource(
        bool contractOrToken,
        string memory source_
    ) external onlyOwner {
        // Updates either the contract or NFT creation source code.
        if (contractOrToken) _contractCreationSource = source_;
        else _nftCreationSource = source_;
    }
}
