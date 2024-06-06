// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IAdsManager.sol";
import "./interfaces/IIPFSManager.sol";
import "./interfaces/ILotteryManager.sol";
import "./interfaces/IPriceFeedManager.sol";
import "./AdsFactory.sol";

/**
 * @title AdsManager
 * @author Andrea Tedesco (@andreatedesco).
 * @dev Manages advertisement-related functionalities, including factory creation, metadata handling,
 * lottery management, and price feed retrieval.
 */
contract AdsManager is IAdsManager, Ownable {
    // =============================================================
    //                               STRUCTS
    // =============================================================

    struct MetadataRequest {
        bool contractOrToken;
        uint256 factoryId;
        uint256 tokenId;
    }

    struct LotteryRequest {
        uint256 factoryId;
        uint256 tokenId;
    }

    // =============================================================
    //                           STATE VARIABLES
    // =============================================================

    // Total supply of factories created.
    uint256 public currentSupply;

    // Interfaces for interacting with other contracts.
    IIPFSManager private _ipfsManager;
    ILotteryManager private _lotteryManager;
    IPriceFeedManager private _priceFeedManager;

    // Mapping from factory ID to its address.
    mapping(uint256 => address) private _factories;

    // Mapping from Chainlink VRF request ID to metadata request details.
    mapping(bytes32 => MetadataRequest) private _metadataRequests;

    // Mapping from Chainlink VRF request ID to lottery request details.
    mapping(uint256 => LotteryRequest) private _lotteryRequests;

    // =============================================================
    //                               EVENTS
    // =============================================================

    // Event emitted when a new AdsFactory contract is created.
    event AdsFactoryCreated(uint256 contractId);

    // =============================================================
    //                               ERRORS
    // =============================================================

    // Error for invalid parameters.
    error ParameterError();

    // Error for unauthorized sender.
    error UnauthorizedSender();

    // =============================================================
    //                          CONSTRUCTOR
    // =============================================================

    /**
     * @dev Constructor that sets the initial addresses of other contract dependencies.
     * @param ipfsManager_ The address of the IPFSManager contract.
     * @param lotteryManager_ The address of the LotteryManager contract.
     * @param priceFeedManager_ The address of the PriceFeedManager contract.
     */
    constructor(
        address ipfsManager_,
        address lotteryManager_,
        address priceFeedManager_
    ) Ownable(_msgSender()) {
        // Initializes contract dependencies.
        updateIPFSManager(ipfsManager_);
        updateLotteryManager(lotteryManager_);
        updatePriceFeedManager(priceFeedManager_);
    }

    // =============================================================
    //                         PUBLIC FUNCTIONS
    // =============================================================

    /**
     * @dev Creates a new AdsFactory contract and initializes its metadata.
     * @param name The name of the factory.
     * @param symbol The symbol of the factory.
     * @param description The description of the factory.
     * @param logo The logo URI of the factory.
     * @param banner The banner URI of the factory.
     * @param site The website URL of the factory.
     * @param royalty The royalty percentage for the factory.
     */
    function createFactory(
        string memory name,
        string memory symbol,
        string memory description,
        string memory logo,
        string memory banner,
        string memory site,
        uint96 royalty
    ) external {
        // Increment current supply to get a unique factory ID.
        uint256 contractId = currentSupply++;
        // Deploy a new AdsFactory contract.
        _factories[contractId] = address(
            new AdsFactory(
                _msgSender(),
                address(this),
                contractId,
                name,
                symbol,
                royalty
            )
        );

        // Metadata arguments for factory creation.
        string[] memory args = new string[](5);
        args[0] = name;
        args[1] = description;
        args[2] = logo;
        args[3] = banner;
        args[4] = site;

        // Create metadata for the factory.
        _createMetadata(true, contractId, 0, args);

        // Emit the AdsFactoryCreated event.
        emit AdsFactoryCreated(contractId);
    }

    /**
     * @dev Creates metadata (NFT or contract) based on the provided arguments.
     * @param contractOrToken Boolean indicating whether to create contract or token metadata.
     * @param factoryId The ID of the AdsFactory contract.
     * @param tokenId The ID of the token (if applicable).
     * @param args Array of string arguments for metadata creation.
     */
    function createMetadata(
        bool contractOrToken,
        uint256 factoryId,
        uint256 tokenId,
        string[] memory args
    ) external override {
        // Ensure only the corresponding AdsFactory contract can call this function.
        if (_msgSender() != _factories[factoryId]) revert UnauthorizedSender();
        // Create metadata based on the provided arguments.
        _createMetadata(contractOrToken, factoryId, tokenId, args);
    }

    /**
     * @dev Sets the IPFS CID for a specific request.
     * @param requestId The Chainlink VRF request ID.
     * @param ipfsUri The IPFS URI to set.
     */
    function setIpfsCID(
        bytes32 requestId,
        string memory ipfsUri
    ) external override {
        // Ensure only the IPFSManager contract can call this function.
        if (_msgSender() != address(_ipfsManager)) revert UnauthorizedSender();
        // Check if the request is for contract metadata or token metadata.
        if (_metadataRequests[requestId].contractOrToken) {
            // Set contract URI in the corresponding AdsFactory contract.
            AdsFactory(_factories[_metadataRequests[requestId].factoryId])
                .setContractUri(ipfsUri);
        } else {
            // Set NFT URI in the corresponding AdsFactory contract.
            AdsFactory(_factories[_metadataRequests[requestId].factoryId])
                .setNFTUri(_metadataRequests[requestId].tokenId, ipfsUri);
        }
    }

    /**
     * @dev Initiates a new lottery using the LotteryManager contract.
     * @param factoryId The ID of the AdsFactory contract.
     * @param tokenId The ID of the token participating in the lottery.
     */
    function startLottery(
        uint256 factoryId,
        uint256 tokenId
    ) external override {
        // Ensure only the corresponding AdsFactory contract can call this function.
        if (_msgSender() != _factories[factoryId]) revert UnauthorizedSender();

        // Start a new lottery and obtain the Chainlink VRF request ID.
        uint256 requestId = _lotteryManager.startLottery();

        // Record the lottery request details.
        _lotteryRequests[requestId] = LotteryRequest(factoryId, tokenId);
    }

    /**
     * @dev Sets the winner of a lottery using the LotteryManager contract.
     * @param requestId The Chainlink VRF request ID.
     * @param randomValue The random value used to determine the winner.
     */
    function setLotteryWinner(
        uint256 requestId,
        uint256 randomValue
    ) external override {
        // Ensure only the LotteryManager contract can call this function.
        if (_msgSender() != address(_lotteryManager))
            revert UnauthorizedSender();
        // Set the winner in the corresponding AdsFactory contract.
        AdsFactory(_factories[_lotteryRequests[requestId].factoryId])
            .setLotteryWinner(_lotteryRequests[requestId].tokenId, randomValue);
    }

    /**
     * @dev Retrieves the native token price for a given USD amount using the PriceFeedManager contract.
     * @param usdAmount The amount in USD for which to retrieve the native token price.
     * @return The native token price.
     */
    function getTokenNativePrice(
        uint256 usdAmount
    ) external view override returns (int) {
        // Retrieve the native token price from the PriceFeedManager contract.
        return _priceFeedManager.getTokenNativePrice(int(usdAmount));
    }

    /**
     * @dev Retrieves an array of AdsFactory contract addresses within a given ID range.
     * @param idMin The minimum ID (inclusive) to start retrieving factories.
     * @param idMax The maximum ID (exclusive) to stop retrieving factories.
     * @return An array of AdsFactory contract addresses.
     */
    function getFactories(
        uint256 idMin,
        uint256 idMax
    ) external view returns (address[] memory) {
        // Validate the input parameters.
        if (idMin >= idMax || idMax > currentSupply) revert ParameterError();
        // Calculate the length of the array to be retrieved.
        uint length = idMax - idMin;
        // Initialize an array to store AdsFactory contract addresses.
        address[] memory factories = new address[](length);

        // Retrieve AdsFactory contract addresses within the specified ID range.
        for (uint256 i = idMin; i < idMax; ++i) {
            factories[i - idMin] = _factories[i];
        }

        return factories;
    }

    // =============================================================
    //                         PRIVATE FUNCTIONS
    // =============================================================

    /**
     * @dev Initiates metadata creation through the IPFSManager contract.
     * @param contractOrToken Boolean indicating whether to create contract or token metadata.
     * @param factoryId The ID of the AdsFactory contract.
     * @param tokenId The ID of the token (if applicable).
     * @param args Array of string arguments for metadata creation.
     */
    function _createMetadata(
        bool contractOrToken,
        uint256 factoryId,
        uint256 tokenId,
        string[] memory args
    ) private {
        bytes32 requestId = _ipfsManager.createMetadata(contractOrToken, args);

        _metadataRequests[requestId] = MetadataRequest(
            contractOrToken,
            factoryId,
            tokenId
        );
    }

    // =============================================================
    //                         OWNER FUNCTIONS
    // =============================================================

    /**
     * @dev Updates the address of the IPFSManager contract.
     * @param ipfsManager_ The new address of the IPFSManager contract.
     */
    function updateIPFSManager(address ipfsManager_) public onlyOwner {
        _ipfsManager = IIPFSManager(ipfsManager_);
    }

    /**
     * @dev Updates the address of the LotteryManager contract.
     * @param lotteryManager_ The new address of the LotteryManager contract.
     */
    function updateLotteryManager(address lotteryManager_) public onlyOwner {
        _lotteryManager = ILotteryManager(lotteryManager_);
    }

    /**
     * @dev Updates the address of the PriceFeedManager contract.
     * @param priceFeedManager_ The new address of the PriceFeedManager contract.
     */
    function updatePriceFeedManager(
        address priceFeedManager_
    ) public onlyOwner {
        _priceFeedManager = IPriceFeedManager(priceFeedManager_);
    }
}
