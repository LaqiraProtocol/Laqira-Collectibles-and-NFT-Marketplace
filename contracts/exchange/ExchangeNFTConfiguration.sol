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

    function setSettings(uint256[] memory keys, uint256[] memory values) external override onlyOwner {
        require(keys.length == values.length, 'length err');
        for (uint256 i; i < keys.length; ++i) {
            emit UpdateSettings(keys[i], settings[keys[i]], values[i]);
            settings[keys[i]] = values[i];
        }
    }

    function setNftEnables(address _nftToken, bool _enable) public override onlyOwner {
        nftEnables[_nftToken] = _enable;
    }

    function setNftQuoteEnables(
        address _nftToken,
        address[] memory _quotes,
        bool _enable
    ) public override onlyOwner {
        EnumerableSetUpgradeable.AddressSet storage quotes = nftQuotes[_nftToken];
        for (uint256 i; i < _quotes.length; i++) {
            nftQuoteEnables[_nftToken][_quotes[i]] = _enable;
            if (!quotes.contains(_quotes[i])) {
                quotes.add(_quotes[i]);
            }
        }
    }

    function transferFeeAddress(
        address _nftToken,
        address _quoteToken,
        address _feeAddress
    ) public override {
        require(_msgSender() == feeAddresses[_nftToken][_quoteToken] || owner() == _msgSender(), 'forbidden');
        emit FeeAddressTransferred(_nftToken, _quoteToken, feeAddresses[_nftToken][_quoteToken], _feeAddress);
        feeAddresses[_nftToken][_quoteToken] = _feeAddress;
    }

    function batchTransferFeeAddress(
        address _nftToken,
        address[] memory _quoteTokens,
        address[] memory _feeAddresses
    ) public override {
        require(_quoteTokens.length == _feeAddresses.length, 'length err');
        for (uint256 i; i < _quoteTokens.length; ++i) {
            transferFeeAddress(_nftToken, _quoteTokens[i], _feeAddresses[i]);
        }
    }
}

