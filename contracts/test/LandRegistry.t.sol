// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/LandRegistry.sol";

contract LandRegistryTest is Test {
    LandRegistry land;
    address admin = address(this);
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        land = new LandRegistry();
    }

    function test_mint_land() public {
        uint256 tokenId = land.mint(alice, 100, 200, 64);
        assertEq(land.ownerOf(tokenId), alice);

        (int64 x, int64 y, uint64 size) = land.plots(tokenId);
        assertEq(x, 100);
        assertEq(y, 200);
        assertEq(size, 64);
    }

    function test_sequential_token_ids() public {
        uint256 id0 = land.mint(alice, 0, 0, 32);
        uint256 id1 = land.mint(alice, 1, 1, 32);
        uint256 id2 = land.mint(bob, 2, 2, 32);

        assertEq(id0, 0);
        assertEq(id1, 1);
        assertEq(id2, 2);
    }

    function test_mint_reverts_without_role() public {
        bytes32 role = land.MINTER_ROLE();
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, bob, role)
        );
        vm.prank(bob);
        land.mint(alice, 0, 0, 32);
    }

    function test_negative_coordinates() public {
        uint256 tokenId = land.mint(alice, -500, -1000, 128);

        (int64 x, int64 y, uint64 size) = land.plots(tokenId);
        assertEq(x, -500);
        assertEq(y, -1000);
        assertEq(size, 128);
    }
}
