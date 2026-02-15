// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/SeasonManager.sol";

contract SeasonManagerTest is Test {
    SeasonManager sm;
    address owner = address(this);
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    // Merkle tree: 2 leaves (alice=1000, bob=500)
    bytes32 leafAlice;
    bytes32 leafBob;
    bytes32 root;

    function setUp() public {
        sm = new SeasonManager();
        leafAlice = keccak256(bytes.concat(keccak256(abi.encode(alice, uint256(1000)))));
        leafBob = keccak256(bytes.concat(keccak256(abi.encode(bob, uint256(500)))));
        root = _hashPair(leafAlice, leafBob);
    }

    function _hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

    function test_start_season() public {
        sm.startSeason();
        assertEq(sm.currentSeasonId(), 1);

        (uint256 startTime,, bytes32 rewardsRoot, bool active) = sm.seasons(1);
        assertGt(startTime, 0);
        assertEq(rewardsRoot, bytes32(0));
        assertTrue(active);
    }

    function test_start_season_reverts_nonowner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        sm.startSeason();
    }

    function test_end_season() public {
        sm.startSeason();
        sm.endSeason(root);

        (,uint256 endTime, bytes32 rewardsRoot, bool active) = sm.seasons(1);
        assertGt(endTime, 0);
        assertEq(rewardsRoot, root);
        assertFalse(active);
    }

    function test_claim_reward_valid_proof() public {
        sm.startSeason();
        sm.endSeason(root);

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = leafBob;

        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit SeasonManager.RewardClaimed(1, alice, 1000);
        sm.claimReward(1, 1000, proof);

        assertTrue(sm.claimed(1, alice));
    }

    function test_claim_reward_double_claim_reverts() public {
        sm.startSeason();
        sm.endSeason(root);

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = leafBob;

        vm.prank(alice);
        sm.claimReward(1, 1000, proof);

        vm.prank(alice);
        vm.expectRevert("Already claimed");
        sm.claimReward(1, 1000, proof);
    }
}
