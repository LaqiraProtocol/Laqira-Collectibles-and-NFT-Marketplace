// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import './royalties/IRoyaltiesProvider.sol';

contract RoyalitiesProvider is IRoyaltiesProvider, Ownable {
    address private LaqiraNFTAddress;
    mapping(address => mapping(uint256 => LibPart.Part[])) private royalties;

    function getRoyalties(address token, uint256 tokenId) external override returns (LibPart.Part[] memory) {
        return royalties[token][tokenId];
    }

    function setRoyalties(address token, uint256 tokenId, LibPart.Part[] memory _royalities) external onlyLaqiraNFT returns (bool) {
        uint256 _len = _royalities.length;
        for (uint256 i = 0; i < _len; i++) {
            royalties[token][tokenId].push(_royalities[i]);
        }
        return true;
    }

    function setLaqiraNFTAddress(address _NFTAddress) public onlyOwner {
        LaqiraNFTAddress = _NFTAddress;
    }

    function getLaqiraNFTAddress() public view returns (address) {
        return LaqiraNFTAddress;
    }

    modifier onlyLaqiraNFT {
        require(msg.sender == LaqiraNFTAddress, 'Only laqira NFT contract');
        _;
    }
}