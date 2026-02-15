// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/ScrapToken.sol";
import "../src/GameItems.sol";
import "../src/LandRegistry.sol";
import "../src/SeasonManager.sol";
import "../src/Marketplace.sol";

contract Deploy is Script {
    function run() external {
        address serverAddress = vm.envAddress("SERVER_ADDRESS");
        address feeRecipient = vm.envAddress("FEE_RECIPIENT");
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerKey);

        ScrapToken scrap = new ScrapToken();
        console.log("ScrapToken:", address(scrap));

        GameItems items = new GameItems();
        console.log("GameItems:", address(items));

        LandRegistry land = new LandRegistry();
        console.log("LandRegistry:", address(land));

        SeasonManager season = new SeasonManager();
        console.log("SeasonManager:", address(season));

        Marketplace market = new Marketplace(address(scrap), feeRecipient);
        console.log("Marketplace:", address(market));

        // Grant MINTER_ROLE to server
        bytes32 minterRole = keccak256("MINTER_ROLE");
        scrap.grantRole(minterRole, serverAddress);
        items.grantRole(minterRole, serverAddress);
        land.grantRole(minterRole, serverAddress);

        console.log("MINTER_ROLE granted to:", serverAddress);

        vm.stopBroadcast();
    }
}
