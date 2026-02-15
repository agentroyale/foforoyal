// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Marketplace - Trading system for NovoJogo items
contract Marketplace is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    uint256 public constant FEE_BPS = 250; // 2.5%
    uint256 public constant BPS_DENOMINATOR = 10000;

    struct Listing {
        address seller;
        address itemContract;
        uint256 itemId;
        uint256 amount;
        uint256 pricePerUnit;
        bool active;
    }

    uint256 private _nextListingId;
    mapping(uint256 => Listing) public listings;
    IERC20 public paymentToken;
    address public feeRecipient;

    event Listed(uint256 indexed listingId, address indexed seller, uint256 itemId, uint256 amount, uint256 price);
    event Bought(uint256 indexed listingId, address indexed buyer, uint256 amount);
    event Cancelled(uint256 indexed listingId);

    constructor(address _paymentToken, address _feeRecipient) Ownable(msg.sender) {
        paymentToken = IERC20(_paymentToken);
        feeRecipient = _feeRecipient;
    }

    function list(address itemContract, uint256 itemId, uint256 amount, uint256 pricePerUnit) external returns (uint256) {
        require(amount > 0, "Amount must be > 0");
        require(pricePerUnit > 0, "Price must be > 0");

        IERC1155(itemContract).safeTransferFrom(msg.sender, address(this), itemId, amount, "");

        uint256 listingId = _nextListingId++;
        listings[listingId] = Listing(msg.sender, itemContract, itemId, amount, pricePerUnit, true);

        emit Listed(listingId, msg.sender, itemId, amount, pricePerUnit);
        return listingId;
    }

    function buy(uint256 listingId, uint256 amount) external nonReentrant {
        Listing storage listing = listings[listingId];
        require(listing.active, "Listing not active");
        require(amount > 0 && amount <= listing.amount, "Invalid amount");

        uint256 totalPrice = amount * listing.pricePerUnit;
        uint256 fee = (totalPrice * FEE_BPS) / BPS_DENOMINATOR;

        paymentToken.safeTransferFrom(msg.sender, listing.seller, totalPrice - fee);
        paymentToken.safeTransferFrom(msg.sender, feeRecipient, fee);

        IERC1155(listing.itemContract).safeTransferFrom(address(this), msg.sender, listing.itemId, amount, "");

        listing.amount -= amount;
        if (listing.amount == 0) {
            listing.active = false;
        }

        emit Bought(listingId, msg.sender, amount);
    }

    function cancel(uint256 listingId) external {
        Listing storage listing = listings[listingId];
        require(listing.seller == msg.sender, "Not seller");
        require(listing.active, "Not active");

        listing.active = false;
        IERC1155(listing.itemContract).safeTransferFrom(address(this), msg.sender, listing.itemId, listing.amount, "");

        emit Cancelled(listingId);
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata) external pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}
