// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import './royalties/IRoyaltiesProvider.sol';

contract RoyaltiesProvider is IRoyaltiesProvider, Ownable {
    mapping(address => bool) private allowedNFTs;
    mapping(address => mapping(uint256 => LibPart.Part[])) private royalties;

    function getRoyalties(address token, uint256 tokenId) external view override returns (LibPart.Part[] memory) {
        return royalties[token][tokenId];
    }

    function setRoyalties(address token, uint256 tokenId, LibPart.Part memory _royalities) external override onlyLaqiraNFT returns (bool) {
        royalties[token][tokenId].push(_royalities);
        return true;
    }

    function setAllowedNFTs(address _NFTAddress, bool permission) public onlyOwner {
        allowedNFTs[_NFTAddress] = permission;
    }

    function isAllowedNFTs(address _NFTAddress) public view returns (bool) {
        return allowedNFTs[_NFTAddress];
    }

    modifier onlyLaqiraNFT {
        require(isAllowedNFTs(_msgSender()), 'Only valid NFTs');
        _;
    }
}