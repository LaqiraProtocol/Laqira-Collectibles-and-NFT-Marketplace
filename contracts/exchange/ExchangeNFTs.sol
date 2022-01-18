// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/math/Math.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import './libraries/EnumerableMap.sol';
import './libraries/ExchangeNFTsHelper.sol';
import './interfaces/IExchangeNFTs.sol';
import './interfaces/IExchangeNFTConfiguration.sol';
contract ExchangeNFTs is IExchangeNFTs, Ownable, ERC721Holder, ReentrancyGuard {
    using SafeMath for uint256;
    using EnumerableMap for EnumerableMap.UintToUintMap;
    using EnumerableSet for EnumerableSet.UintSet;

    struct SettleTrade {
        address nftToken;
        address quoteToken;
        address buyer;
        address seller;
        uint256 tokenId;
        uint256 originPrice;
        uint256 price;
        bool isMaker;
    }

    struct AskEntry {
        uint256 tokenId;
        uint256 price;
    }

    struct BidEntry {
        address bidder;
        uint256 price;
    }

    struct UserBidEntry {
        uint256 tokenId;
        uint256 price;
    }

    IExchangeNFTConfiguration public config;
     // nft => tokenId => seller
    mapping(address => mapping(uint256 => address)) public tokenSellers;
    // nft => tokenId => quote
    mapping(address => mapping(uint256 => address)) public tokenSelleOn;
    // nft => quote => tokenId,price
    mapping(address => mapping(address => EnumerableMap.UintToUintMap)) private _asksMaps;
    // nft => quote => seller => tokenIds
    mapping(address => mapping(address => mapping(address => EnumerableSet.UintSet)))
        private _userSellingTokens;
    // nft => quote => tokenId => bid
    mapping(address => mapping(address => mapping(uint256 => BidEntry[]))) public tokenBids;
    // nft => quote => buyer => tokenId,bid
    mapping(address => mapping(address => mapping(address => EnumerableMap.UintToUintMap))) private _userBids;
    // nft => tokenId => status (0 - can sell and bid, 1 - only bid)
    mapping(address => mapping(uint256 => uint256)) tokenSelleStatus;

    constructor(address _config) {
        config = IExchangeNFTConfiguration(_config);
    }

    function setConfig(address _config) public onlyOwner {
        require(address(config) != _config, 'forbidden');
        config = IExchangeNFTConfiguration(_config);
    }

    function getNftQuotes(address _nftToken) public view override returns (address[] memory) {
        return config.getNftQuotes(_nftToken);
    }

    function batchReadyToSellToken(
        address[] memory _nftTokens,
        uint256[] memory _tokenIds,
        address[] memory _quoteTokens,
        uint256[] memory _prices,
        uint256[] memory _selleStatus
    ) external override {
        batchReadyToSellTokenTo(_nftTokens, _tokenIds, _quoteTokens, _prices, _selleStatus, _msgSender());
    }

    function batchReadyToSellTokenTo(
        address[] memory _nftTokens,
        uint256[] memory _tokenIds,
        address[] memory _quoteTokens,
        uint256[] memory _prices,
        uint256[] memory _selleStatus,
        address _to
    ) public override {
        require(
            _nftTokens.length == _tokenIds.length &&
                _tokenIds.length == _quoteTokens.length &&
                _quoteTokens.length == _prices.length,
            'length err'
        );
        for (uint256 i = 0; i < _nftTokens.length; i++) {
            readyToSellTokenTo(_nftTokens[i], _tokenIds[i], _quoteTokens[i], _prices[i], _to, _selleStatus[i]);
        }
    }

    function readyToSellToken(
        address _nftToken,
        uint256 _tokenId,
        address _quoteToken,
        uint256 _price,
        uint256 _selleStatus
    ) external override {
        readyToSellTokenTo(_nftToken, _tokenId, _quoteToken, _price, _msgSender(), _selleStatus);
    }

    function readyToSellToken(
        address _nftToken,
        uint256 _tokenId,
        address _quoteToken,
        uint256 _price
    ) external override {
        readyToSellTokenTo(_nftToken, _tokenId, _quoteToken, _price, _msgSender(), 0);
    }

    function readyToSellTokenTo(
        address _nftToken,
        uint256 _tokenId,
        address _quoteToken,
        uint256 _price,
        address _to,
        uint256 _selleStatus
    ) public override nonReentrant {
        config.whenSettings(0, 0);
        config.checkEnableTrade(_nftToken, _quoteToken);
        require(_msgSender() == IERC721(_nftToken).ownerOf(_tokenId), 'Only Token Owner can sell token');
        require(_price != 0, 'Price must be granter than zero');
        IERC721(_nftToken).safeTransferFrom(_msgSender(), address(this), _tokenId);
        _asksMaps[_nftToken][_quoteToken].set(_tokenId, _price);
        tokenSellers[_nftToken][_tokenId] = _to;
        tokenSelleOn[_nftToken][_tokenId] = _quoteToken;
        _userSellingTokens[_nftToken][_quoteToken][_to].add(_tokenId);
        tokenSelleStatus[_nftToken][_tokenId] = _selleStatus;
        emit Ask(_nftToken, _msgSender(), _tokenId, _quoteToken, _price);
    }
}