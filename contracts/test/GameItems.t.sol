// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/GameItems.sol";

contract GameItemsTest is Test {
    GameItems items;
    address admin = address(this);
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        items = new GameItems();
    }

    function test_mint_single() public {
        items.mint(alice, 1, 10, "");
        assertEq(items.balanceOf(alice, 1), 10);
    }

    function test_mint_batch() public {
        uint256[] memory ids = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;
        amounts[0] = 10;
        amounts[1] = 20;
        amounts[2] = 30;

        items.mintBatch(alice, ids, amounts, "");

        assertEq(items.balanceOf(alice, 1), 10);
        assertEq(items.balanceOf(alice, 2), 20);
        assertEq(items.balanceOf(alice, 3), 30);
    }

    function test_mint_reverts_without_role() public {
        bytes32 role = items.MINTER_ROLE();
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, bob, role)
        );
        vm.prank(bob);
        items.mint(alice, 1, 10, "");
    }

    function test_burn_by_owner() public {
        items.mint(alice, 1, 10, "");

        vm.prank(alice);
        items.burn(alice, 1, 5);
        assertEq(items.balanceOf(alice, 1), 5);
    }

    function test_burn_reverts_unauthorized() public {
        items.mint(alice, 1, 10, "");

        vm.prank(bob);
        vm.expectRevert("Not authorized");
        items.burn(alice, 1, 5);
    }
}
