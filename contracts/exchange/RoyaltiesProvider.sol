// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import './royalties/IRoyaltiesProvider.sol';

contract RoyaltiesProvider is IRoyaltiesProvider, Ownable {
    mapping(address => bool) private allowedNFTs;
    mapping(address => mapping(uint256 => LibPart.Part[])) private royalties;
    uint96 private totalRoyalties;

    function getRoyalties(address token, uint256 tokenId) external view override returns (LibPart.Part[] memory) {
        return royalties[token][tokenId];
    }

    function setRoyalties(address token, uint256 tokenId, address[] calldata royaltyOwners, uint96[] calldata values) external override onlyAllowedNFTs returns (bool) {
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

    function setAllowedNFTs(address _NFTAddress, bool permission) public onlyOwner {
        allowedNFTs[_NFTAddress] = permission;
    }

    function isAllowedNFTs(address _NFTAddress) public view returns (bool) {
        return allowedNFTs[_NFTAddress];
    }

    function getTotalRoyalties() public view returns (uint96) {
        return totalRoyalties;
    }

    modifier onlyAllowedNFTs {
        require(isAllowedNFTs(_msgSender()), 'Only valid NFTs');
        _;
    }
}