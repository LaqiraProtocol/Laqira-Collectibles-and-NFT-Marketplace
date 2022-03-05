// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import './royalties/IRoyaltiesProvider.sol';

// This smart contract is deployed as royaltiesProvider of "Laqira" collectibles.

contract RoyaltiesProvider is IRoyaltiesProvider, Ownable {
    address private allowedNFT;
    mapping(address => mapping(uint256 => LibPart.Part[])) private royalties;
    uint96 private totalRoyalties;

    function getRoyalties(address token, uint256 tokenId) external view override returns (LibPart.Part[] memory) {
        return royalties[token][tokenId];
    }

    function setRoyalties(address token, uint256 tokenId, address[] calldata royaltyOwners, uint96[] calldata values) external override onlyAllowedNFT returns (bool) {
        require(royaltyOwners.length == values.length, 'Invalid length');
        uint96 _totalRoyalties;
        for (uint256 i = 0; i < values.length; i++) {
            _totalRoyalties += values[i];
        }
        require(_totalRoyalties <= totalRoyalties, 'Invalid total royalties');
        for (uint256 i = 0; i < values.length; i++) {
            royalties[token][tokenId].push(LibPart.Part({account: payable(royaltyOwners[i]), value: values[i]}));
        }
        return true;
    }

    function setTotalRoyalties(uint96 _value) public onlyOwner {
        totalRoyalties = _value;
    }

    function setAllowedNFT(address _NFTAddress) public onlyOwner {
        allowedNFT = _NFTAddress;
    }

    function getAllowedNFT() public view returns (address) {
        return allowedNFT;
    }

    function getTotalRoyalties() public view returns (uint96) {
        return totalRoyalties;
    }

    modifier onlyAllowedNFT {
        require(msg.sender == allowedNFT, 'Only allowedNFT');
        _;
    }
}