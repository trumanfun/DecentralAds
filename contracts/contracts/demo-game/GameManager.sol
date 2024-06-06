// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";
import "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title GameManager
 * @author Andrea Tedesco (@andreatedesco).
 * @dev This contract represents a game manager that facilitates the automated distribution
 * of ERC721 non-fungible tokens (NFTs) to the winner of a challenge. The challenge has a specified
 * end date, and the contract utilizes Chainlink Functions to determine
 * the winner based on certain game statistics.
 */

contract GameManager is
    Ownable,
    ERC721Holder,
    FunctionsClient,
    AutomationCompatibleInterface
{
    using FunctionsRequest for FunctionsRequest.Request;

    // =============================================================
    //                           STATE VARIABLES
    // =============================================================

    // Address of the winner of the challenge.
    address public winner;

    // End date for the challenge in UNIX timestamp format (20 December 2023 22:00:00 UTC).
    uint256 public endDate = 1703109600;

    // Flag indicating whether NFTs have been sent.
    bool public nftsSended;

    // ERC721 contract instance representing the NFT factory.
    IERC721 public factory;

    // Subscription ID for Chainlink Functions.
    uint64 public subscriptionId = 1750;

    // Encrypted secrets for secure data transmission.
    bytes public encryptedSecretsUrls =
        hex"3e1d02d274f82e20df6b75193cc7b9d202d3e1841dee24913f2d5c5efb3c51bb813aba0b77e269b8c94106c394e311fa6ec2916704e1f2aed1ad9ee11e7891ebd0afe6fc6c11a6dfa63aa590539fe38e25f88ec5da2103d0f809026288dba6ce49f3e643feebd856a47ab4a98f92449cf3b8fc5fd538ed09e7595df512c2b2c285af7ce9cdfc605cf16f376dc530e5f749";

    // The router address for Chainlink requests.
    address public router = 0xA9d587a00A31A52Ed70D6026794a8FC5E2F5dCb0;

    // Donation ID for Chainlink requests.
    bytes32 public donId =
        0x66756e2d6176616c616e6368652d66756a692d31000000000000000000000000;

    // Gas limit for Chainlink requests.
    uint32 public gasLimit = 300000;

    // Mapping to store errors for each request.
    mapping(bytes32 => bytes) public errors;

    // JavaScript source code for obtaining the winner.
    string private _source =
        "const titleId = '3EA44';"
        "const statisticName = 'level';"
        "const startPosition = 0;"
        "const maxResultsCount = 1;"
        "const getLeaderboardUrl = `https://${titleId}.playfabapi.com/Server/GetLeaderboard?StatisticName=${statisticName}&StartPosition=${startPosition}&MaxResultsCount=${maxResultsCount}`;"
        "const getUserAccountInfoUrl = `https://${titleId}.playfabapi.com/Server/GetUserAccountInfo`;"
        "const leaderboardReq = await Functions.makeHttpRequest({"
        "url: getLeaderboardUrl,"
        "method: 'POST',"
        "headers: {"
        "'Content-Type': 'application/json',"
        "'Accept-Encoding': 'identity',"
        "'X-SecretKey': secrets.playfabApiKey"
        "},"
        "});"
        "if (leaderboardReq.error) throw new Error(`${leaderboardReq.message}`);"
        "const playFabId = leaderboardReq.data.data.Leaderboard[0].PlayFabId;"
        "const apiResponse = await Functions.makeHttpRequest({"
        "url: getUserAccountInfoUrl,"
        "method: 'POST',"
        "headers: {"
        "'Content-Type': 'application/json',"
        "'Accept-Encoding': 'identity',"
        "'X-SecretKey': secrets.playfabApiKey"
        "},"
        "params:{"
        "'PlayFabID': playFabId,"
        "}"
        "});"
        "if (apiResponse.error) throw new Error(`${apiResponse.message}`);"
        "return Functions.encodeString(apiResponse.data.data.UserInfo.CustomIdInfo.CustomId);";

    // =============================================================
    //                               EVENTS
    // =============================================================

    /**
     * @dev Emitted when a challenge is successfully fulfilled.
     * @param winner The address of the participant who successfully completed the challenge.
     * @param errors Any errors that occurred during the fulfillment process.
     */
    event ChallengeFulfilled(address winner, bytes errors);

    // =============================================================
    //                          CONSTRUCTOR
    // =============================================================

    /**
     * @dev Constructor that sets the router address and initializes FunctionsClient.
     * @param factory_ The address of the factory contract.
     */
    constructor(
        address factory_
    ) FunctionsClient(router) Ownable(_msgSender()) {
        factory = IERC721(factory_);
    }

    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        upkeepNeeded = block.timestamp > endDate && !nftsSended;
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        if (block.timestamp > endDate && !nftsSended) {
            _sendRequest();
        }
    }

    /**
     * @dev Initiates the process of sending NFTs to the winner.
     */
    function _sendRequest() private {
        nftsSended = true;

        // Initializes the FunctionsRequest with the appropriate source code.
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(_source);
        req.addSecretsReference(encryptedSecretsUrls);

        // Sends the request and obtains the Chainlink Functions request ID.
        _sendRequest(req.encodeCBOR(), subscriptionId, gasLimit, donId);
    }

    // =============================================================
    //                         INTERNAL FUNCTIONS
    // =============================================================

    /**
     * @dev Fulfills the Chainlink Functions request, transfers NFTs to the winner, and logs errors.
     * @param requestId The Chainlink Functions request ID.
     * @param response The response containing the winner's information.
     * @param err The error message, if any.
     */
    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        errors[requestId] = err;
        winner = _toAddress(string(response));

        // Transfers NFTs to the winner.
        factory.safeTransferFrom(address(this), winner, 0);
        factory.safeTransferFrom(address(this), winner, 1);

        emit ChallengeFulfilled(winner, err);
    }

    /**
     * @dev Converts a hex string to an address.
     * @param s The hex string.
     * @return tempAddress The converted address.
     */
    function _toAddress(string memory s) private pure returns (address) {
        bytes memory _bytes = _hexStringToAddress(s);
        require(_bytes.length >= 1 + 20, "Out of bounds");
        address tempAddress;

        assembly {
            tempAddress := div(
                mload(add(add(_bytes, 0x20), 1)),
                0x1000000000000000000000000
            )
        }

        return tempAddress;
    }

    /**
     * @dev Converts a hex string to bytes.
     * @param s The hex string.
     * @return r The converted bytes.
     */
    function _hexStringToAddress(
        string memory s
    ) private pure returns (bytes memory) {
        bytes memory ss = bytes(s);
        require(ss.length % 2 == 0); // length must be even
        bytes memory r = new bytes(ss.length / 2);
        for (uint i = 0; i < ss.length / 2; ++i) {
            r[i] = bytes1(
                _fromHexChar(uint8(ss[2 * i])) *
                    16 +
                    _fromHexChar(uint8(ss[2 * i + 1]))
            );
        }

        return r;
    }

    /**
     * @dev Converts a hex character to a uint8.
     * @param c The hex character.
     * @return The converted uint8 value.
     */
    function _fromHexChar(uint8 c) private pure returns (uint8) {
        if (bytes1(c) >= bytes1('0') && bytes1(c) <= bytes1('9')) {
            return c - uint8(bytes1('0'));
        }
        if (bytes1(c) >= bytes1('a') && bytes1(c) <= bytes1('f')) {
            return 10 + c - uint8(bytes1('a'));
        }
        if (bytes1(c) >= bytes1('A') && bytes1(c) <= bytes1('F')) {
            return 10 + c - uint8(bytes1('A'));
        }
        return 0;
    }

    // =============================================================
    //                         OWNER FUNCTIONS
    // =============================================================

    /**
     * @dev Updates the NFT factory contract address.
     * @param factory_ The new NFT factory contract address.
     */
    function updateFactory(address factory_) external onlyOwner {
        factory = IERC721(factory_);
    }

    /**
     * @dev Updates the end date for the challenge.
     * @param endDate_ The new end date in UNIX timestamp format.
     */
    function updateEndDate(uint256 endDate_) external onlyOwner {
        endDate = endDate_;
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
     * @param source_ The new source code.
     */
    function updateSource(string memory source_) external onlyOwner {
        _source = source_;
    }

    // =============================================================
    //                              TEST
    // =============================================================

    /**
     * @dev Initiates the process of sending NFTs for testing purposes.
     */
    function sendRequest() public onlyOwner {
        _sendRequest();
    }
}
