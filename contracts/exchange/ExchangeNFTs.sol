// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/math/Math.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import './libraries/EnumerableMap.sol';
import './libraries/ExchangeNFTsHelper.sol';
import './interfaces/IExchangeNFTs.sol';
import './interfaces/IExchangeNFTConfiguration.sol';
contract ExchangeNFTs {
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
}