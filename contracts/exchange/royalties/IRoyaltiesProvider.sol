// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import './LibPart.sol';

interface IRoyaltiesProvider {
    function getRoyalties(uint256 tokenId) external view returns (LibPart.Part[] memory);
    function setRoyalties(uint256 tokenId, address[] calldata royaltyOwners, uint96[] calldata values) external returns (bool);
    event TotalRoyaltiesSet(uint96 _oldValue, uint96 _newValue);
}