// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import './LibPart.sol';

interface IRoyaltiesProvider {
    function getRoyalties(address token, uint256 tokenId) external returns (LibPart.Part[] memory);
    function setRoyalties(address token, uint256 tokenId, LibPart.Part[] memory _royalities) external returns (bool);
}