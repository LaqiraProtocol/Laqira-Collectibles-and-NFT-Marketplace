// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import './interfaces/IExchangeNFTConfiguration.sol';

contract ExchangeNFTConfiguration is IExchangeNFTConfiguration, Ownable {
    using EnumerableSet for EnumerableSetUpgradeable.AddressSet;

    /**
      global settings
      settings[0] = 0; // enable readyToSellToken
      settings[1] = 0; // enable setCurrentPrice
      settings[2] = 0; // enable buyToken
      settings[3] = 0; // enable cancelSellToken
      settings[4] = 0; // enable bidToken
      settings[5] = 0; // enable updateBidPrice
      settings[6] = 0; // enable sellTokenTo
      settings[7] = 0; // enable cancelBidToken
    */
    mapping(uint256 => uint256) public override settings;
    // nft => is enable
    mapping(address => bool) public override nftEnables;
    // nft => quote => is enable
    mapping(address => mapping(address => bool)) public override nftQuoteEnables;
    // nft => quote => fee burnable
    mapping(address => mapping(address => bool)) public override feeBurnables;
    // nft => quote => fee address
    mapping(address => mapping(address => address)) public override feeAddresses;
    // nft => quote => fee
    mapping(address => mapping(address => uint256)) public override feeValues;
    // nft => quote => royalties provider
    mapping(address => mapping(address => address)) public override royaltiesProviders;
    // nft => quote => royalties burnable
    mapping(address => mapping(address => bool)) public override royaltiesBurnables;
    // nft => quotes
    mapping(address => EnumerableSet.AddressSet) private nftQuotes;
}
