// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title LandRegistry - ERC-721 land plot NFTs for NovoJogo
/// @notice Each token represents a land plot at (x, y) with a given size
contract LandRegistry is ERC721, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    struct LandPlot {
        int64 x;
        int64 y;
        uint64 size;
    }

    uint256 private _nextTokenId;
    mapping(uint256 => LandPlot) public plots;

    constructor() ERC721("NovoJogo Land", "LAND") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    function mint(address to, int64 x, int64 y, uint64 size) external onlyRole(MINTER_ROLE) returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        plots[tokenId] = LandPlot(x, y, size);
        _mint(to, tokenId);
        return tokenId;
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
