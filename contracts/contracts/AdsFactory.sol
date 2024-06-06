// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/interfaces/IERC4906.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/IAdsManager.sol";

/**
 * @title AdsFactory
 * @author Andrea Tedesco (@andreatedesco).
 * @dev This contract represents an AdsFactory that allows users to create and manage NFTs with optional lottery features.
 */
contract AdsFactory is Ownable, IERC4906, ERC721Royalty {
    // =============================================================
    //                               STRUCTS
    // =============================================================

    // Struct to store data related to individual ads.
    struct AdData {
        uint256 mintPrice;
        uint32 width;
        uint32 height;
        string ipfsUri;
        address reservedFor;
        bool isLottery;
    }

    // Struct to store data related to lotteries.
    struct LotteryData {
        uint256 ticketPrice;
        uint16 ticketAmountToStart;
        address[] addresses;
    }

    // =============================================================
    //                           STATE VARIABLES
    // =============================================================

    // Counter for the total supply of NFTs.
    uint256 public currentSupply;

    // Address of the AdsManager contract.
    IAdsManager public adsManager;

    // ID of the AdsFactory.
    uint256 public factoryId;

    // Contract-level URI for external use.
    string private _contractUri;

    // Mapping from token ID to AdData.
    mapping(uint256 => AdData) private _ads;

    // Mapping from token ID to LotteryData (for lottery-enabled NFTs).
    mapping(uint256 => LotteryData) private _lotteries; //adId -> data

    // Minimum amount of wei to be considered as rest after a transaction.
    uint256 private constant MIN_REST = 1 wei;

    // =============================================================
    //                               EVENTS
    // =============================================================

    // Event emitted when contract metadata is updated.
    event ContractMetadataUpdate();

    // Event emitted when a new NFT is added.
    event AdAdded(uint256 tokenId);

    // Event emitted when a lottery ticket is purchased.
    event TicketPurchased(uint256 tokenId);

    // Event emitted when a lottery is completed.
    event LotteryCompleted(uint256 tokenId, address winner);

    // =============================================================
    //                               ERRORS
    // =============================================================

    // Error thrown when attempting an operation on a non-existent NFT.
    error NonexistentAd(uint256 tokenId);

    // Error thrown when attempting to purchase a lottery ticket for a closed lottery.
    error LotteryClosed(uint256 tokenId);

    // Error thrown when the sent value is insufficient for a transaction.
    error InsufficientAmount(uint256 amount);

    // Error thrown when the fee payment fails.
    error FeePaymentFailed();

    // Error thrown when the payment for an operation fails.
    error PaymentFailed();

    // Error thrown when attempting to mint an NFT that is reserved for another address.
    error AdReserved(uint256 tokenId);

    // Error thrown when attempting to reserve a lottery-enabled NFT.
    error LotteryOpen(uint256 tokenId);

    // Error thrown when attempting to update the metadata of an NFT that is not owned by the sender.
    error AdNotOwned(uint256 tokenId);

    // Error thrown when there is an error in the provided parameters.
    error ParameterError();

    // Error thrown when the contract owner encounters an error during a withdrawal.
    error WithdrawalError();

    // Error thrown when an unauthorized sender attempts an operation.
    error UnauthorizedSender(address sender);

    // =============================================================
    //                             MODIFIERS
    // =============================================================

    /**
     * @dev Modifier to restrict a function to only the AdsManager contract.
     */
    modifier onlyAdsManager() {
        if (address(adsManager) != _msgSender()) {
            revert UnauthorizedSender(_msgSender());
        }
        _;
    }

    // =============================================================
    //                          CONSTRUCTOR
    // =============================================================

    /**
     * @dev Constructor to initialize the AdsFactory contract.
     * @param admin The address that will be set as the owner of the AdsFactory.
     * @param adsManager_ The address of the AdsManager contract.
     * @param factoryId_ The ID of the AdsFactory.
     * @param name_ The name of the ERC721 token.
     * @param symbol_ The symbol of the ERC721 token.
     * @param royalty The royalty percentage for the ERC721Royalty contract.
     */
    constructor(
        address admin,
        address adsManager_,
        uint256 factoryId_,
        string memory name_,
        string memory symbol_,
        uint96 royalty
    ) ERC721(name_, symbol_) Ownable(admin) {
        factoryId = factoryId_;
        adsManager = IAdsManager(adsManager_);
        _setDefaultRoyalty(admin, royalty);
    }

    // =============================================================
    //                         PUBLIC FUNCTIONS
    // =============================================================

    /**
     * @dev Allows users to purchase a lottery ticket for a specific NFT.
     * @param tokenId The ID of the NFT.
     */
    function buyTicket(uint256 tokenId) external payable {
        if (!_exist(tokenId)) revert NonexistentAd(tokenId);

        if (
            _lotteries[tokenId].addresses.length >=
            _lotteries[tokenId].ticketAmountToStart
        ) revert LotteryClosed(tokenId);

        uint256 price = uint256(
            adsManager.getTokenNativePrice(_lotteries[tokenId].ticketPrice)
        );

        _pay(price, msg.value);

        _lotteries[tokenId].addresses.push(_msgSender());

        if (
            _lotteries[tokenId].addresses.length ==
            _lotteries[tokenId].ticketAmountToStart
        ) {
            adsManager.startLottery(factoryId, tokenId);
        }

        emit TicketPurchased(tokenId);
    }

    /**
     * @dev Allows users to mint an NFT.
     * @param tokenId The ID of the NFT.
     * @param name The name of the NFT.
     * @param description The description of the NFT.
     * @param image The image URI of the NFT.
     * @param site The external link of the NFT.
     */
    function mintAd(
        uint256 tokenId,
        string calldata name,
        string calldata description,
        string calldata image,
        string calldata site
    ) external payable {
        if (_ads[tokenId].reservedFor != address(0)) {
            if (_ads[tokenId].reservedFor != _msgSender())
                revert AdReserved(tokenId);
        } else {
            if (_ads[tokenId].isLottery) revert LotteryOpen(tokenId);
        }

        uint256 price = uint256(
            adsManager.getTokenNativePrice(_ads[tokenId].mintPrice)
        );

        _pay(price, msg.value);

        _updateAd(tokenId, name, description, image, site);
        _mint(_msgSender(), tokenId);
    }

    /**
     * @dev Allows users to update the metadata of their owned NFT.
     * @param tokenId The ID of the NFT.
     * @param name The new name of the NFT.
     * @param description The new description of the NFT.
     * @param image The new image URI of the NFT.
     * @param site The new external link of the NFT.
     */
    function updateAd(
        uint256 tokenId,
        string calldata name,
        string calldata description,
        string calldata image,
        string calldata site
    ) public {
        if (ownerOf(tokenId) != _msgSender()) revert AdNotOwned(tokenId);
        _updateAd(tokenId, name, description, image, site);
    }

    /**
     * @dev Returns the IPFS URI of a specific NFT.
     * @param tokenId The ID of the NFT.
     */
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        return _ads[tokenId].ipfsUri;
    }

    /**
     * @dev Returns the contract-level URI.
     */
    function contractURI() external view returns (string memory) {
        return _contractUri;
    }

    /**
     * @dev Returns the data associated with a specific NFT.
     * @param tokenId The ID of the NFT.
     */
    function getAdData(uint256 tokenId) external view returns (AdData memory) {
        return _ads[tokenId];
    }

    /**
     * @dev Returns the lottery data associated with a specific NFT.
     * @param tokenId The ID of the NFT.
     */
    function getLotteryData(
        uint256 tokenId
    ) external view returns (LotteryData memory) {
        return _lotteries[tokenId];
    }

    /**
     * @dev Returns the owner of an NFT without the safety checks.
     * @param tokenId The ID of the NFT.
     */
    function ownerOfUnsafe(uint256 tokenId) public view returns (address) {
        return _ownerOf(tokenId);
    }

    /**
     * @dev See {ERC721Royalty-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(IERC165, ERC721Royalty) returns (bool) {
        return
            interfaceId == bytes4(0x49064906) ||
            ERC721Royalty.supportsInterface(interfaceId) ||
            ERC721.supportsInterface(interfaceId);
    }

    // =============================================================
    //                         PRIVATE FUNCTIONS
    // =============================================================

    /**
     * @dev Updates the metadata of a specific NFT.
     * @param tokenId The ID of the NFT.
     * @param name The new name of the NFT.
     * @param description The new description of the NFT.
     * @param image The new image URI of the NFT.
     * @param site The new external link of the NFT.
     */
    function _updateAd(
        uint256 tokenId,
        string calldata name,
        string calldata description,
        string calldata image,
        string calldata site
    ) private {
        if (!_exist(tokenId)) revert NonexistentAd(tokenId);

        bool isLottery = _ads[tokenId].isLottery;
        string[] memory args = new string[](isLottery ? 8 : 7);
        args[0] = name;
        args[1] = description;
        args[2] = image;
        args[3] = site;
        args[4] = Strings.toString(_ads[tokenId].width);
        args[5] = Strings.toString(_ads[tokenId].height);
        args[6] = Strings.toString(
            isLottery
                ? _lotteries[tokenId].ticketPrice
                : _ads[tokenId].mintPrice
        );
        if (isLottery)
            args[7] = Strings.toString(_lotteries[tokenId].ticketAmountToStart);
        adsManager.createMetadata(false, factoryId, tokenId, args);
    }

    /**
     * @dev Handles the payment logic for purchasing a ticket or minting an NFT.
     * @param price The price of the operation.
     * @param msgValue The amount sent with the transaction.
     */
    function _pay(uint256 price, uint256 msgValue) private {
        if (price > 0) {
            if (price > msgValue) revert InsufficientAmount(msgValue);

            uint256 rest = msgValue - price;
            if (rest > MIN_REST) {
                (bool restSent, ) = _msgSender().call{value: rest}("");
                if (!restSent) revert PaymentFailed();
            }

            uint256 fee = ((msgValue - rest) / 10000) * 200;
            (bool feeSent, ) = Ownable(address(adsManager)).owner().call{
                value: fee
            }("");
            if (!feeSent) revert FeePaymentFailed();
        }
    }

    /**
     * @dev Checks if an NFT with a given ID exists.
     * @param tokenId The ID of the NFT.
     */
    function _exist(uint256 tokenId) private view returns (bool) {
        return _ads[tokenId].width > 0;
    }

    // =============================================================
    //                         OWNER FUNCTIONS
    // =============================================================

    /**
     * @dev Adds multiple NFTs with specified configurations to the factory.
     * @param prices The prices for each NFT.
     * @param widths The widths for each NFT.
     * @param heights The heights for each NFT.
     * @param ticketsToStart The ticket amounts to start lotteries for each NFT (set to 0 if not a lottery).
     * @param whitelists The reserved addresses for each NFT (set to address(0) if not reserved).
     */
    function addAds(
        uint256[] calldata prices,
        uint32[] calldata widths,
        uint32[] calldata heights,
        uint16[] calldata ticketsToStart,
        address[] calldata whitelists
    ) external onlyOwner {
        if (
            !(prices.length == widths.length &&
                prices.length == heights.length &&
                prices.length == ticketsToStart.length &&
                prices.length == whitelists.length)
        ) {
            revert ParameterError();
        }

        for (uint i = 0; i < prices.length; ++i) {
            addAd(
                prices[i],
                widths[i],
                heights[i],
                ticketsToStart[i],
                whitelists[i]
            );
        }
    }

    /**
     * @dev Adds a single NFT with a specified configuration to the factory.
     * @param price The price for the NFT.
     * @param width The width for the NFT.
     * @param height The height for the NFT.
     * @param ticketAmountToStart The ticket amount to start the lottery for the NFT (set to 0 if not a lottery).
     * @param reservedFor The reserved address for the NFT (set to address(0) if not reserved).
     */
    function addAd(
        uint256 price,
        uint32 width,
        uint32 height,
        uint16 ticketAmountToStart,
        address reservedFor
    ) public onlyOwner {
        if (width == 0 || height == 0) revert ParameterError();

        uint256 tokenId = currentSupply++;
        bool isLottery = ticketAmountToStart > 0;

        _ads[tokenId] = AdData(
            isLottery ? 0 : price,
            width,
            height,
            "",
            isLottery ? address(0) : reservedFor,
            isLottery
        );

        if (isLottery) {
            _lotteries[tokenId] = LotteryData(
                price,
                ticketAmountToStart,
                new address[](0)
            );
        }

        emit AdAdded(tokenId);
    }

    /**
     * @dev Updates the contract metadata with the provided information.
     * @param name The name of the contract.
     * @param description The description of the contract.
     * @param logo The logo of the contract.
     * @param banner The banner of the contract.
     * @param site The website of the contract.
     */
    function updateContractMetadata(
        string memory name,
        string memory description,
        string memory logo,
        string memory banner,
        string memory site
    ) public onlyOwner {
        string[] memory args = new string[](5);
        args[0] = name;
        args[1] = description;
        args[2] = logo;
        args[3] = banner;
        args[4] = site;
        adsManager.createMetadata(true, factoryId, 0, args);
    }

    /**
     * @dev Allows the contract owner to withdraw the contract's balance.
     */
    function withdraw() external virtual onlyOwner {
        (bool sent, ) = _msgSender().call{value: address(this).balance}("");
        if (!sent) revert WithdrawalError();
    }

    // =============================================================
    //                       ADS MANAGER FUNCTIONS
    // =============================================================

    /**
     * @dev Sets the contract URI for external use.
     * @param uri The URI to be set.
     */
    function setContractUri(string memory uri) external onlyAdsManager {
        _contractUri = uri;
        emit ContractMetadataUpdate();
    }

    /**
     * @dev Sets the URI for a specific NFT token.
     * @param tokenId The ID of the NFT token.
     * @param uri The URI to be set.
     */
    function setNFTUri(
        uint256 tokenId,
        string memory uri
    ) external onlyAdsManager {
        _ads[tokenId].ipfsUri = uri;
        emit MetadataUpdate(tokenId);
    }

    /**
     * @dev Sets the winner of a lottery and updates the reserved address for the associated NFT token.
     * @param tokenId The ID of the NFT token associated with the lottery.
     * @param randomValue The random value used to determine the winner.
     */
    function setLotteryWinner(
        uint256 tokenId,
        uint256 randomValue
    ) external onlyAdsManager {
        address winner = _lotteries[tokenId].addresses[
            randomValue % _lotteries[tokenId].addresses.length
        ];
        _ads[tokenId].reservedFor = winner;
        emit LotteryCompleted(tokenId, winner);
    }
}
