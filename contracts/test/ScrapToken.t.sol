// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/ScrapToken.sol";

contract ScrapTokenTest is Test {
    ScrapToken token;
    address admin = address(this);
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        token = new ScrapToken();
    }

    function test_mint_by_minter() public {
        token.mint(alice, 1000 ether);
        assertEq(token.balanceOf(alice), 1000 ether);
    }

    function test_mint_reverts_without_role() public {
        bytes32 role = token.MINTER_ROLE();
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, bob, role)
        );
        vm.prank(bob);
        token.mint(alice, 100 ether);
    }

    function test_grant_minter_role() public {
        token.grantRole(token.MINTER_ROLE(), bob);

        vm.prank(bob);
        token.mint(alice, 500 ether);
        assertEq(token.balanceOf(alice), 500 ether);
    }

    function test_revoke_minter_role() public {
        bytes32 role = token.MINTER_ROLE();
        token.grantRole(role, bob);
        token.revokeRole(role, bob);

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, bob, role)
        );
        vm.prank(bob);
        token.mint(alice, 100 ether);
    }
}
