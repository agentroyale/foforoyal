// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/LandRegistry.sol";
import "../src/GameItems.sol";
import "../src/ScrapToken.sol";

/// @notice Phase 0: Sanity tests to verify contracts compile and deploy
contract SanityTest is Test {
    function test_land_registry_deploys() public {
        LandRegistry land = new LandRegistry();
        assertEq(land.name(), "NovoJogo Land");
        assertEq(land.symbol(), "LAND");
    }

    function test_game_items_deploys() public {
        GameItems items = new GameItems();
        assertTrue(address(items) != address(0));
    }

    function test_scrap_token_deploys() public {
        ScrapToken scrap = new ScrapToken();
        assertEq(scrap.name(), "Scrap");
        assertEq(scrap.symbol(), "SCRAP");
        assertEq(scrap.totalSupply(), 0);
    }
}
