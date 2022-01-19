// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

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

    function setFee(
        address _nftToken,
        address _quoteToken,
        uint256 _feeValue
    ) public override onlyOwner {
        emit SetFee(_nftToken, _quoteToken, _msgSender(), feeValues[_nftToken][_quoteToken], _feeValue);
        feeValues[_nftToken][_quoteToken] = _feeValue;
    }

    function batchSetFee(
        address _nftToken,
        address[] memory _quoteTokens,
        uint256[] memory _feeValues
    ) public override onlyOwner {
        require(_quoteTokens.length == _feeValues.length, 'length err');
        for (uint256 i; i < _quoteTokens.length; ++i) {
            setFee(_nftToken, _quoteTokens[i], _feeValues[i]);
        }
    }

    function setFeeBurnAble(
        address _nftToken,
        address _quoteToken,
        bool _feeBurnable
    ) public override onlyOwner {
        emit SetFeeBurnAble(_nftToken, _quoteToken, _msgSender(), feeBurnables[_nftToken][_quoteToken], _feeBurnable);
        feeBurnables[_nftToken][_quoteToken] = _feeBurnable;
    }

    function batchSetFeeBurnAble(
        address _nftToken,
        address[] memory _quoteTokens,
        bool[] memory _feeBurnables
    ) public override onlyOwner {
        require(_quoteTokens.length == _feeBurnables.length, 'length err');
        for (uint256 i; i < _quoteTokens.length; ++i) {
            setFeeBurnAble(_nftToken, _quoteTokens[i], _feeBurnables[i]);
        }
    }

    function setRoyaltiesProvider(
        address _nftToken,
        address _quoteToken,
        address _royaltiesProvider
    ) public override onlyOwner {
        emit SetRoyaltiesProvider(
            _nftToken,
            _quoteToken,
            _msgSender(),
            royaltiesProviders[_nftToken][_quoteToken],
            _royaltiesProvider
        );
        royaltiesProviders[_nftToken][_quoteToken] = _royaltiesProvider;
    }

    function batchSetRoyaltiesProviders(
        address _nftToken,
        address[] memory _quoteTokens,
        address[] memory _royaltiesProviders
    ) public override onlyOwner {
        require(_quoteTokens.length == _royaltiesProviders.length, 'length err');
        for (uint256 i; i < _quoteTokens.length; ++i) {
            setRoyaltiesProvider(_nftToken, _quoteTokens[i], _royaltiesProviders[i]);
        }
    }

    function setRoyaltiesBurnable(
        address _nftToken,
        address _quoteToken,
        bool _royaltiesBurnable
    ) public override onlyOwner {
        emit SetRoyaltiesBurnable(
            _nftToken,
            _quoteToken,
            _msgSender(),
            royaltiesBurnables[_nftToken][_quoteToken],
            _royaltiesBurnable
        );
        royaltiesBurnables[_nftToken][_quoteToken] = _royaltiesBurnable;
    }

    function batchSetRoyaltiesBurnable(
        address _nftToken,
        address[] memory _quoteTokens,
        bool[] memory _royaltiesBurnables
    ) public override onlyOwner {
        require(_quoteTokens.length == _royaltiesBurnables.length, 'length err');
        for (uint256 i; i < _quoteTokens.length; ++i) {
            setRoyaltiesBurnable(_nftToken, _quoteTokens[i], _royaltiesBurnables[i]);
        }
    }

    function addNft(
        address _nftToken,
        bool _enable,
        address[] memory _quotes,
        address[] memory _feeAddresses,
        uint256[] memory _feeValues,
        bool[] memory _feeBurnAbles,
        address[] memory _royaltiesProviders,
        bool[] memory _royaltiesBurnables
    ) external override onlyOwner {
        require(
            _quotes.length == _feeAddresses.length &&
                _feeAddresses.length == _feeValues.length &&
                _feeValues.length == _feeBurnAbles.length &&
                _feeBurnAbles.length == _royaltiesProviders.length &&
                _royaltiesProviders.length == _royaltiesBurnables.length,
            'length err'
        );
        setNftEnables(_nftToken, _enable);
        setNftQuoteEnables(_nftToken, _quotes, true);
        batchTransferFeeAddress(_nftToken, _quotes, _feeAddresses);
        batchSetFee(_nftToken, _quotes, _feeValues);
        batchSetFeeBurnAble(_nftToken, _quotes, _feeBurnAbles);
        batchSetRoyaltiesProviders(_nftToken, _quotes, _royaltiesProviders);
        batchSetRoyaltiesBurnable(_nftToken, _quotes, _royaltiesBurnables);
    }

    function nftSettings(address _nftToken, address _quoteToken) external view override returns (NftSettings memory) {
        return
            NftSettings({
                enable: nftEnables[_nftToken],
                nftQuoteEnable: nftQuoteEnables[_nftToken][_quoteToken],
                feeAddress: feeAddresses[_nftToken][_quoteToken],
                feeBurnAble: feeBurnables[_nftToken][_quoteToken],
                feeValue: feeValues[_nftToken][_quoteToken],
                royaltiesProvider: royaltiesProviders[_nftToken][_quoteToken],
                royaltiesBurnable: royaltiesBurnables[_nftToken][_quoteToken]
            });
    }

    function checkEnableTrade(address _nftToken, address _quoteToken) external view override {
        // nft disable
        require(nftEnables[_nftToken], 'nft disable');
        // quote disable
        require(nftQuoteEnables[_nftToken][_quoteToken], 'quote disable');
    }

    function whenSettings(uint256 key, uint256 value) external view override {
        require(settings[key] == value, 'settings err');
    }

    function getNftQuotes(address _nftToken) external view override returns (address[] memory quotes) {
        quotes = new address[](nftQuotes[_nftToken].length());
        for (uint256 i = 0; i < nftQuotes[_nftToken].length(); ++i) {
            quotes[i] = nftQuotes[_nftToken].at(i);
        }
    }
}