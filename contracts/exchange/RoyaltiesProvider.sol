// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import './royalties/IRoyaltiesProvider.sol';

// This smart contract is deployed as royaltiesProvider of "Laqira" collectibles.

contract RoyaltiesProvider is IRoyaltiesProvider, OwnableUpgradeable {
    address private allowedNFT;
    uint96 private totalRoyalties;
    mapping(uint256 => LibPart.Part[]) private royalties;

    function initialize(uint96 totalRoyalties_) public initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
        totalRoyalties = totalRoyalties_;
    }

    function getRoyalties(uint256 tokenId) external virtual view override returns (LibPart.Part[] memory) {
        return royalties[tokenId];
    }

    function setRoyalties(uint256 tokenId, address[] calldata royaltyOwners, uint96[] calldata values) external
    virtual override onlyAllowedNFT returns (bool) {
        require(royaltyOwners.length == values.length, 'Invalid length');
        uint96 _totalRoyalties;
        for (uint256 i = 0; i < values.length; i++) {
            require(royaltyOwners[i] != address(0), 'Zero address cannot be royaltyOwner');
            _totalRoyalties += values[i];
        }
        require(_totalRoyalties <= totalRoyalties, 'Invalid total royalties');
        for (uint256 i = 0; i < values.length; i++) {
            royalties[tokenId].push(LibPart.Part({account: payable(royaltyOwners[i]), value: values[i]}));
        }
        return true;
    }

    function setTotalRoyalties(uint96 _value) public virtual onlyOwner {
        emit TotalRoyaltiesSet(totalRoyalties, _value);
        totalRoyalties = _value;
    }

    function setAllowedNFT(address _NFTAddress) public virtual onlyOwner {
        allowedNFT = _NFTAddress;
    }

    function getAllowedNFT() public virtual view returns (address) {
        return allowedNFT;
    }

    function getTotalRoyalties() public virtual view returns (uint96) {
        return totalRoyalties;
    }

    modifier onlyAllowedNFT {
        require(msg.sender == getAllowedNFT(), 'Only allowedNFT');
        _;
    }
}