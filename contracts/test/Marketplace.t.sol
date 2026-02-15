// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/Marketplace.sol";
import "../src/ScrapToken.sol";
import "../src/GameItems.sol";

contract MarketplaceTest is Test {
    Marketplace market;
    ScrapToken scrap;
    GameItems items;

    address admin = address(this);
    address seller = makeAddr("seller");
    address buyer = makeAddr("buyer");
    address feeRecipient = makeAddr("feeRecipient");

    uint256 constant ITEM_ID = 1;
    uint256 constant ITEM_AMOUNT = 100;
    uint256 constant PRICE_PER_UNIT = 10 ether;

    function setUp() public {
        scrap = new ScrapToken();
        items = new GameItems();
        market = new Marketplace(address(scrap), feeRecipient);

        // Mint items to seller
        items.mint(seller, ITEM_ID, ITEM_AMOUNT, "");

        // Mint scrap to buyer
        scrap.mint(buyer, 100_000 ether);

        // Approvals
        vm.prank(seller);
        items.setApprovalForAll(address(market), true);

        vm.prank(buyer);
        scrap.approve(address(market), type(uint256).max);
    }

    function test_list_item() public {
        vm.prank(seller);
        uint256 listingId = market.list(address(items), ITEM_ID, ITEM_AMOUNT, PRICE_PER_UNIT);

        (address s, address ic, uint256 iid, uint256 amt, uint256 ppu, bool active) = market.listings(listingId);
        assertEq(s, seller);
        assertEq(ic, address(items));
        assertEq(iid, ITEM_ID);
        assertEq(amt, ITEM_AMOUNT);
        assertEq(ppu, PRICE_PER_UNIT);
        assertTrue(active);

        // Items transferred to marketplace
        assertEq(items.balanceOf(address(market), ITEM_ID), ITEM_AMOUNT);
        assertEq(items.balanceOf(seller, ITEM_ID), 0);
    }

    function test_buy_full_listing() public {
        vm.prank(seller);
        uint256 listingId = market.list(address(items), ITEM_ID, ITEM_AMOUNT, PRICE_PER_UNIT);

        uint256 totalPrice = ITEM_AMOUNT * PRICE_PER_UNIT;
        uint256 fee = (totalPrice * 250) / 10000; // 2.5%

        uint256 sellerBefore = scrap.balanceOf(seller);
        uint256 feeBefore = scrap.balanceOf(feeRecipient);

        vm.prank(buyer);
        market.buy(listingId, ITEM_AMOUNT);

        assertEq(scrap.balanceOf(seller), sellerBefore + totalPrice - fee);
        assertEq(scrap.balanceOf(feeRecipient), feeBefore + fee);
        assertEq(items.balanceOf(buyer, ITEM_ID), ITEM_AMOUNT);

        (,,,,, bool active) = market.listings(listingId);
        assertFalse(active);
    }

    function test_buy_partial() public {
        vm.prank(seller);
        uint256 listingId = market.list(address(items), ITEM_ID, ITEM_AMOUNT, PRICE_PER_UNIT);

        uint256 buyAmount = 40;
        vm.prank(buyer);
        market.buy(listingId, buyAmount);

        (,,, uint256 remaining,, bool active) = market.listings(listingId);
        assertEq(remaining, ITEM_AMOUNT - buyAmount);
        assertTrue(active);
        assertEq(items.balanceOf(buyer, ITEM_ID), buyAmount);
    }

    function test_buy_reverts_inactive() public {
        vm.prank(seller);
        uint256 listingId = market.list(address(items), ITEM_ID, ITEM_AMOUNT, PRICE_PER_UNIT);

        vm.prank(seller);
        market.cancel(listingId);

        vm.prank(buyer);
        vm.expectRevert("Listing not active");
        market.buy(listingId, 1);
    }

    function test_cancel_listing() public {
        vm.prank(seller);
        uint256 listingId = market.list(address(items), ITEM_ID, ITEM_AMOUNT, PRICE_PER_UNIT);

        vm.prank(seller);
        market.cancel(listingId);

        (,,,,, bool active) = market.listings(listingId);
        assertFalse(active);
        assertEq(items.balanceOf(seller, ITEM_ID), ITEM_AMOUNT);
    }

    function test_cancel_reverts_not_seller() public {
        vm.prank(seller);
        uint256 listingId = market.list(address(items), ITEM_ID, ITEM_AMOUNT, PRICE_PER_UNIT);

        vm.prank(buyer);
        vm.expectRevert("Not seller");
        market.cancel(listingId);
    }

    function test_fee_calculation() public {
        // Large-scale math: 1_000_000 items at 1_000 ether each
        uint256 bigAmount = 1_000_000;
        uint256 bigPrice = 1_000 ether;

        items.mint(seller, 99, bigAmount, "");
        scrap.mint(buyer, bigAmount * bigPrice);

        vm.prank(seller);
        items.setApprovalForAll(address(market), true);

        vm.prank(seller);
        uint256 listingId = market.list(address(items), 99, bigAmount, bigPrice);

        uint256 totalPrice = bigAmount * bigPrice;
        uint256 expectedFee = (totalPrice * 250) / 10000;

        uint256 feeBefore = scrap.balanceOf(feeRecipient);

        vm.prank(buyer);
        scrap.approve(address(market), type(uint256).max);

        vm.prank(buyer);
        market.buy(listingId, bigAmount);

        assertEq(scrap.balanceOf(feeRecipient) - feeBefore, expectedFee);
        assertEq(expectedFee, 25_000_000 ether); // 2.5% of 1e9 ether
    }
}
