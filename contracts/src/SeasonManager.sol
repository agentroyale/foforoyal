// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/// @title SeasonManager - Wipe/season system for NovoJogo
contract SeasonManager is Ownable {
    struct Season {
        uint256 startTime;
        uint256 endTime;
        bytes32 rewardsRoot;
        bool active;
    }

    uint256 public currentSeasonId;
    mapping(uint256 => Season) public seasons;
    mapping(uint256 => mapping(address => bool)) public claimed;

    event SeasonStarted(uint256 indexed seasonId, uint256 startTime);
    event SeasonEnded(uint256 indexed seasonId, uint256 endTime, bytes32 rewardsRoot);
    event RewardClaimed(uint256 indexed seasonId, address indexed player, uint256 amount);

    constructor() Ownable(msg.sender) {}

    function startSeason() external onlyOwner {
        if (currentSeasonId > 0) {
            require(!seasons[currentSeasonId].active, "Current season still active");
        }
        currentSeasonId++;
        seasons[currentSeasonId] = Season(block.timestamp, 0, bytes32(0), true);
        emit SeasonStarted(currentSeasonId, block.timestamp);
    }

    function endSeason(bytes32 rewardsRoot) external onlyOwner {
        Season storage season = seasons[currentSeasonId];
        require(season.active, "No active season");
        season.endTime = block.timestamp;
        season.rewardsRoot = rewardsRoot;
        season.active = false;
        emit SeasonEnded(currentSeasonId, block.timestamp, rewardsRoot);
    }

    function claimReward(uint256 seasonId, uint256 amount, bytes32[] calldata proof) external {
        require(!claimed[seasonId][msg.sender], "Already claimed");
        Season storage season = seasons[seasonId];
        require(!season.active, "Season still active");
        require(season.rewardsRoot != bytes32(0), "No rewards set");

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, amount))));
        require(MerkleProof.verify(proof, season.rewardsRoot, leaf), "Invalid proof");

        claimed[seasonId][msg.sender] = true;
        emit RewardClaimed(seasonId, msg.sender, amount);
    }
}
