// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

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
import './royalties/IRoyaltiesProvider.sol';
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
                _quoteTokens.length == _prices.length &&
                _prices.length == _selleStatus.length,
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

    function batchSetCurrentPrice(
        address[] memory _nftTokens,
        uint256[] memory _tokenIds,
        address[] memory _quoteTokens,
        uint256[] memory _prices
    ) external override {
        require(
            _nftTokens.length == _tokenIds.length &&
                _tokenIds.length == _quoteTokens.length &&
                _quoteTokens.length == _prices.length,
            'length err'
        );
        for (uint256 i = 0; i < _nftTokens.length; i++) {
            setCurrentPrice(_nftTokens[i], _tokenIds[i], _quoteTokens[i], _prices[i]);
        }
    }

    function setCurrentPrice(
        address _nftToken,
        uint256 _tokenId,
        address _quoteToken,
        uint256 _price
    ) public override nonReentrant {
        config.whenSettings(1, 0);
        config.checkEnableTrade(_nftToken, _quoteToken);
        require(
            _userSellingTokens[_nftToken][_quoteToken][_msgSender()].contains(_tokenId),
            'Only Seller can update price'
        );
        require(_price != 0, 'Price must be granter than zero');
        _asksMaps[_nftToken][_quoteToken].set(_tokenId, _price);
        emit Ask(_nftToken, _msgSender(), _tokenId, _quoteToken, _price);
    }

    function batchBuyToken(
        address[] memory _nftTokens,
        uint256[] memory _tokenIds,
        address[] memory _quoteTokens,
        uint256[] memory _prices
    ) external override {
        batchBuyTokenTo(_nftTokens, _tokenIds, _quoteTokens, _prices, _msgSender());
    }

    function batchBuyTokenTo(
        address[] memory _nftTokens,
        uint256[] memory _tokenIds,
        address[] memory _quoteTokens,
        uint256[] memory _prices,
        address _to
    ) public override {
        require(
            _nftTokens.length == _tokenIds.length &&
                _tokenIds.length == _quoteTokens.length &&
                _quoteTokens.length == _prices.length,
            'length err'
        );
        for (uint256 i = 0; i < _nftTokens.length; i++) {
            buyTokenTo(_nftTokens[i], _tokenIds[i], _quoteTokens[i], _prices[i], _to);
        }
    }

    function buyToken(
        address _nftToken,
        uint256 _tokenId,
        address _quoteToken,
        uint256 _price
    ) external payable override {
        buyTokenTo(_nftToken, _tokenId, _quoteToken, _price, _msgSender());
    }

    function _settleTrade(SettleTrade memory settleTrade) internal {
        IExchangeNFTConfiguration.NftSettings memory nftSettings =
            config.nftSettings(settleTrade.nftToken, settleTrade.quoteToken);
        uint256 feeAmount = settleTrade.price.mul(nftSettings.feeValue).div(10000);
        address transferTokenFrom = settleTrade.isMaker ? address(this) : _msgSender();
        if (feeAmount != 0) {
            if (nftSettings.feeBurnAble) {
                ExchangeNFTsHelper.burnToken(settleTrade.quoteToken, transferTokenFrom, feeAmount);
            } else {
                ExchangeNFTsHelper.transferToken(
                    settleTrade.quoteToken,
                    transferTokenFrom,
                    nftSettings.feeAddress,
                    feeAmount
                );
            }
        }
        uint256 restValue = settleTrade.price.sub(feeAmount);
        if (nftSettings.royaltiesProvider != address(0)) {
            LibPart.Part[] memory fees =
                IRoyaltiesProvider(nftSettings.royaltiesProvider).getRoyalties(
                    settleTrade.tokenId
                );
            for (uint256 i = 0; i < fees.length; i++) {
                uint256 feeValue = settleTrade.price.mul(fees[i].value).div(10000);
                if (restValue > feeValue) {
                    restValue = restValue.sub(feeValue);
                } else {
                    feeValue = restValue;
                    restValue = 0;
                }
                if (feeValue != 0) {
                    feeAmount = feeAmount.add(feeValue);
                    if (nftSettings.royaltiesBurnable) {
                        ExchangeNFTsHelper.burnToken(settleTrade.quoteToken, transferTokenFrom, feeValue);
                    } else {
                        ExchangeNFTsHelper.transferToken(
                            settleTrade.quoteToken,
                            transferTokenFrom,
                            fees[i].account,
                            feeValue
                        );
                    }
                }
            }
        }

        ExchangeNFTsHelper.transferToken(settleTrade.quoteToken, transferTokenFrom, settleTrade.seller, restValue);

        _asksMaps[settleTrade.nftToken][settleTrade.quoteToken].remove(settleTrade.tokenId);
        _userSellingTokens[settleTrade.nftToken][settleTrade.quoteToken][settleTrade.seller].remove(
            settleTrade.tokenId
        );
        IERC721(settleTrade.nftToken).safeTransferFrom(
            address(this),
            settleTrade.buyer,
            settleTrade.tokenId
        );
        emit Trade(
            settleTrade.nftToken,
            settleTrade.quoteToken,
            settleTrade.seller,
            settleTrade.buyer,
            settleTrade.tokenId,
            settleTrade.originPrice,
            settleTrade.price,
            feeAmount
        );
        delete tokenSellers[settleTrade.nftToken][settleTrade.tokenId];
        delete tokenSelleOn[settleTrade.nftToken][settleTrade.tokenId];
        delete tokenSelleStatus[settleTrade.nftToken][settleTrade.tokenId];
    }

    function buyTokenTo(
        address _nftToken,
        uint256 _tokenId,
        address _quoteToken,
        uint256 _price,
        address _to
    ) public payable override nonReentrant {
        config.whenSettings(2, 0);
        config.checkEnableTrade(_nftToken, _quoteToken);
        require(tokenSelleOn[_nftToken][_tokenId] == _quoteToken, 'quote token err');
        require(_asksMaps[_nftToken][_quoteToken].contains(_tokenId), 'Token not in sell book');
        require(!_userBids[_nftToken][_quoteToken][_msgSender()].contains(_tokenId), 'You must cancel your bid first');
        uint256 price = _asksMaps[_nftToken][_quoteToken].get(_tokenId);
        require(_price == price, 'Wrong price');
        require(
            (msg.value == 0 && _quoteToken != ExchangeNFTsHelper.ETH_ADDRESS) ||
                (_quoteToken == ExchangeNFTsHelper.ETH_ADDRESS && msg.value == _price),
            'error msg value'
        );
        require(tokenSelleStatus[_nftToken][_tokenId] == 0, 'only bid');
        _settleTrade(
            SettleTrade({
                nftToken: _nftToken,
                quoteToken: _quoteToken,
                buyer: _to,
                seller: tokenSellers[_nftToken][_tokenId],
                tokenId: _tokenId,
                originPrice: price,
                price: _price,
                isMaker: _quoteToken == ExchangeNFTsHelper.ETH_ADDRESS ? true : false
            })
        );
    }

    function batchCancelSellToken(address[] memory _nftTokens, uint256[] memory _tokenIds) external override {
        require(_nftTokens.length == _tokenIds.length);
        for (uint256 i = 0; i < _nftTokens.length; i++) {
            cancelSellToken(_nftTokens[i], _tokenIds[i]);
        }
    }

    function cancelSellToken(address _nftToken, uint256 _tokenId) public override nonReentrant {
        config.whenSettings(3, 0);
        require(tokenSellers[_nftToken][_tokenId] == _msgSender(), 'Only Seller can cancel sell token');
        IERC721(_nftToken).safeTransferFrom(address(this), _msgSender(), _tokenId);
        _userSellingTokens[_nftToken][tokenSelleOn[_nftToken][_tokenId]][_msgSender()].remove(_tokenId);
        emit CancelSellToken(
            _nftToken,
            tokenSelleOn[_nftToken][_tokenId],
            _msgSender(),
            _tokenId,
            _asksMaps[_nftToken][tokenSelleOn[_nftToken][_tokenId]].get(_tokenId)
        );
        _asksMaps[_nftToken][tokenSelleOn[_nftToken][_tokenId]].remove(_tokenId);
        delete tokenSellers[_nftToken][_tokenId];
        delete tokenSelleOn[_nftToken][_tokenId];
        delete tokenSelleStatus[_nftToken][_tokenId];
    }

    // bid
    function batchBidToken(
        address[] memory _nftTokens,
        uint256[] memory _tokenIds,
        address[] memory _quoteTokens,
        uint256[] memory _prices
    ) external override {
        batchBidTokenTo(_nftTokens, _tokenIds, _quoteTokens, _prices, _msgSender());
    }

    function batchBidTokenTo(
        address[] memory _nftTokens,
        uint256[] memory _tokenIds,
        address[] memory _quoteTokens,
        uint256[] memory _prices,
        address _to
    ) public override {
        require(
            _nftTokens.length == _tokenIds.length &&
                _tokenIds.length == _quoteTokens.length &&
                _quoteTokens.length == _prices.length,
            'length err'
        );
        for (uint256 i = 0; i < _nftTokens.length; i++) {
            bidTokenTo(_nftTokens[i], _tokenIds[i], _quoteTokens[i], _prices[i], _to);
        }
    }

    function bidToken(
        address _nftToken,
        uint256 _tokenId,
        address _quoteToken,
        uint256 _price
    ) external payable override {
        bidTokenTo(_nftToken, _tokenId, _quoteToken, _price, _msgSender());
    }

    function bidTokenTo(
        address _nftToken,
        uint256 _tokenId,
        address _quoteToken,
        uint256 _price,
        address _to
    ) public payable override nonReentrant {
        config.whenSettings(4, 0);
        config.checkEnableTrade(_nftToken, _quoteToken);
        require(_price != 0, 'Price must be granter than zero');
        require(_asksMaps[_nftToken][_quoteToken].contains(_tokenId), 'Token not in sell book');
        require(tokenSellers[_nftToken][_tokenId] != _to, 'Owner cannot bid');
        require(!_userBids[_nftToken][_quoteToken][_to].contains(_tokenId), 'Bidder already exists');
        require(
            (msg.value == 0 && _quoteToken != ExchangeNFTsHelper.ETH_ADDRESS) ||
                (_quoteToken == ExchangeNFTsHelper.ETH_ADDRESS && msg.value == _price),
            'error msg value'
        );
        if (_quoteToken != ExchangeNFTsHelper.ETH_ADDRESS) {
            TransferHelper.safeTransferFrom(_quoteToken, _msgSender(), address(this), _price);
        }
        _userBids[_nftToken][_quoteToken][_to].set(_tokenId, _price);
        tokenBids[_nftToken][_quoteToken][_tokenId].push(BidEntry({bidder: _to, price: _price}));
        emit Bid(_nftToken, _to, _tokenId, _quoteToken, _price);
    }

     function batchUpdateBidPrice(
        address[] memory _nftTokens,
        uint256[] memory _tokenIds,
        address[] memory _quoteTokens,
        uint256[] memory _prices
    ) external override {
        require(
            _nftTokens.length == _tokenIds.length &&
                _tokenIds.length == _quoteTokens.length &&
                _quoteTokens.length == _prices.length,
            'length err'
        );
        for (uint256 i = 0; i < _nftTokens.length; i++) {
            updateBidPrice(_nftTokens[i], _tokenIds[i], _quoteTokens[i], _prices[i]);
        }
    }

    function updateBidPrice(
        address _nftToken,
        uint256 _tokenId,
        address _quoteToken,
        uint256 _price
    ) public payable override nonReentrant {
        config.whenSettings(5, 0);
        config.checkEnableTrade(_nftToken, _quoteToken);
        require(
            _userBids[_nftToken][_quoteToken][_msgSender()].contains(_tokenId),
            'Only Bidder can update the bid price'
        );
        require(_price != 0, 'Price must be granter than zero');
        address _to = _msgSender(); // find  bid and the index
        (BidEntry memory bidEntry, uint256 _index) = getBidByTokenIdAndAddress(_nftToken, _quoteToken, _tokenId, _to);
        require(bidEntry.price != 0, 'Bidder does not exist');
        require(bidEntry.price != _price, 'The bid price cannot be the same');
        require(
            (_quoteToken != ExchangeNFTsHelper.ETH_ADDRESS && msg.value == 0) ||
                _quoteToken == ExchangeNFTsHelper.ETH_ADDRESS,
            'error msg value'
        );
        if (_price > bidEntry.price) {
            require(
                _quoteToken != ExchangeNFTsHelper.ETH_ADDRESS || msg.value == _price.sub(bidEntry.price),
                'error msg value.'
            );
            ExchangeNFTsHelper.transferToken(_quoteToken, _msgSender(), address(this), _price.sub(bidEntry.price));
        } else {
            ExchangeNFTsHelper.transferToken(_quoteToken, address(this), _msgSender(), bidEntry.price.sub(_price));
        }
        _userBids[_nftToken][_quoteToken][_to].set(_tokenId, _price);
        tokenBids[_nftToken][_quoteToken][_tokenId][_index] = BidEntry({bidder: _to, price: _price});
        emit Bid(_nftToken, _to, _tokenId, _quoteToken, _price);
    }

    function getBidByTokenIdAndAddress(
        address _nftToken,
        address _quoteToken,
        uint256 _tokenId,
        address _address
    ) internal view virtual returns (BidEntry memory, uint256) {
        // find the index of the bid
        BidEntry[] memory bidEntries = tokenBids[_nftToken][_quoteToken][_tokenId];
        uint256 len = bidEntries.length;
        uint256 _index;
        BidEntry memory bidEntry;
        for (uint256 i = 0; i < len; i++) {
            if (_address == bidEntries[i].bidder) {
                _index = i;
                bidEntry = BidEntry({bidder: bidEntries[i].bidder, price: bidEntries[i].price});
                break;
            }
        }
        return (bidEntry, _index);
    }

    function delBidByTokenIdAndIndex(
        address _nftToken,
        address _quoteToken,
        uint256 _tokenId,
        uint256 _index
    ) internal virtual {
        _userBids[_nftToken][_quoteToken][tokenBids[_nftToken][_quoteToken][_tokenId][_index].bidder].remove(_tokenId);
        // delete the bid
        uint256 len = tokenBids[_nftToken][_quoteToken][_tokenId].length;
        for (uint256 i = _index; i < len - 1; i++) {
            tokenBids[_nftToken][_quoteToken][_tokenId][i] = tokenBids[_nftToken][_quoteToken][_tokenId][i + 1];
        }
        tokenBids[_nftToken][_quoteToken][_tokenId].pop();
    }

    function sellTokenTo(
        address _nftToken,
        uint256 _tokenId,
        address _quoteToken,
        uint256 _price,
        address _to
    ) public override nonReentrant {
        config.whenSettings(6, 0);
        config.checkEnableTrade(_nftToken, _quoteToken);
        require(_asksMaps[_nftToken][_quoteToken].contains(_tokenId), 'Token not in sell book');
        require(tokenSellers[_nftToken][_tokenId] == _msgSender(), 'Only owner can sell token');
        // find  bid and the index
        (BidEntry memory bidEntry, uint256 _index) = getBidByTokenIdAndAddress(_nftToken, _quoteToken, _tokenId, _to);
        require(bidEntry.price != 0, 'Bidder does not exist');
        require(_price == bidEntry.price, 'Wrong price');
        uint256 originPrice = _asksMaps[_nftToken][_quoteToken].get(_tokenId);
        _settleTrade(
            SettleTrade({
                nftToken: _nftToken,
                quoteToken: _quoteToken,
                buyer: _to,
                seller: tokenSellers[_nftToken][_tokenId],
                tokenId: _tokenId,
                originPrice: originPrice,
                price: bidEntry.price,
                isMaker: true
            })
        );

        delBidByTokenIdAndIndex(_nftToken, _quoteToken, _tokenId, _index);
    }

     function batchCancelBidToken(
        address[] memory _nftTokens,
        address[] memory _quoteTokens,
        uint256[] memory _tokenIds
    ) external override {
        require(_nftTokens.length == _quoteTokens.length && _quoteTokens.length == _tokenIds.length, 'length err');
        for (uint256 i = 0; i < _nftTokens.length; i++) {
            cancelBidToken(_nftTokens[i], _quoteTokens[i], _tokenIds[i]);
        }
    }

    function cancelBidToken(
        address _nftToken,
        address _quoteToken,
        uint256 _tokenId
    ) public override nonReentrant {
        config.whenSettings(7, 0);
        require(_userBids[_nftToken][_quoteToken][_msgSender()].contains(_tokenId), 'Only Bidder can cancel the bid');
        // find  bid and the index
        (BidEntry memory bidEntry, uint256 _index) =
            getBidByTokenIdAndAddress(_nftToken, _quoteToken, _tokenId, _msgSender());
        require(bidEntry.price != 0, 'Bidder does not exist');
        ExchangeNFTsHelper.transferToken(_quoteToken, address(this), _msgSender(), bidEntry.price);
        emit CancelBidToken(_nftToken, _quoteToken, _msgSender(), _tokenId, bidEntry.price);
        delBidByTokenIdAndIndex(_nftToken, _quoteToken, _tokenId, _index);
    }

    function getAskLength(address _nftToken, address _quoteToken) public view returns (uint256) {
        return _asksMaps[_nftToken][_quoteToken].length();
    }

    function getAsks(address _nftToken, address _quoteToken) public view returns (AskEntry[] memory) {
        AskEntry[] memory asks = new AskEntry[](_asksMaps[_nftToken][_quoteToken].length());
        for (uint256 i = 0; i < _asksMaps[_nftToken][_quoteToken].length(); ++i) {
            (uint256 tokenId, uint256 price) = _asksMaps[_nftToken][_quoteToken].at(i);
            asks[i] = AskEntry({tokenId: tokenId, price: price});
        }
        return asks;
    }

    function getAsksByNFT(address _nftToken)
        external
        view
        returns (
            address[] memory quotes,
            uint256[] memory lengths,
            AskEntry[] memory asks
        )
    {
        quotes = getNftQuotes(_nftToken);
        lengths = new uint256[](quotes.length);
        uint256 total = 0;
        for (uint256 i = 0; i < quotes.length; ++i) {
            lengths[i] = getAskLength(_nftToken, quotes[i]);
            total = total + lengths[i];
        }
        asks = new AskEntry[](total);
        uint256 index = 0;
        for (uint256 i = 0; i < quotes.length; ++i) {
            AskEntry[] memory tempAsks = getAsks(_nftToken, quotes[i]);
            for (uint256 j = 0; j < tempAsks.length; ++j) {
                asks[index] = tempAsks[j];
                ++index;
            }
        }
    }

    function getAsksByPage(
        address _nftToken,
        address _quoteToken,
        uint256 _page,
        uint256 _size
    ) external view returns (AskEntry[] memory) {
        if (_asksMaps[_nftToken][_quoteToken].length() > 0) {
            uint256 from = _page == 0 ? 0 : (_page - 1) * _size;
            uint256 to =
                Math.min((_page == 0 ? 1 : _page) * _size, _asksMaps[_nftToken][_quoteToken].length());
            AskEntry[] memory asks = new AskEntry[]((to - from));
            for (uint256 i = 0; from < to; ++i) {
                (uint256 tokenId, uint256 price) = _asksMaps[_nftToken][_quoteToken].at(from);
                asks[i] = AskEntry({tokenId: tokenId, price: price});
                ++from;
            }
            return asks;
        } else {
            return new AskEntry[](0);
        }
    }

    function getUserAsks(
        address _nftToken,
        address _quoteToken,
        address _user
    ) public view returns (AskEntry[] memory) {
        AskEntry[] memory asks = new AskEntry[](_userSellingTokens[_nftToken][_quoteToken][_user].length());
        for (uint256 i = 0; i < _userSellingTokens[_nftToken][_quoteToken][_user].length(); ++i) {
            uint256 tokenId = _userSellingTokens[_nftToken][_quoteToken][_user].at(i);
            uint256 price = _asksMaps[_nftToken][_quoteToken].get(tokenId);
            asks[i] = AskEntry({tokenId: tokenId, price: price});
        }
        return asks;
    }

    function getUserAsksByNFT(address _nftToken, address _user)
        external
        view
        returns (
            address[] memory quotes,
            uint256[] memory lengths,
            AskEntry[] memory asks
        )
    {
        quotes = getNftQuotes(_nftToken);
        lengths = new uint256[](quotes.length);
        uint256 total = 0;
        for (uint256 i = 0; i < quotes.length; ++i) {
            lengths[i] = _userSellingTokens[_nftToken][quotes[i]][_user].length();
            total = total + lengths[i];
        }
        asks = new AskEntry[](total);
        uint256 index = 0;
        for (uint256 i = 0; i < quotes.length; ++i) {
            AskEntry[] memory tempAsks = getUserAsks(_nftToken, quotes[i], _user);
            for (uint256 j = 0; j < tempAsks.length; ++j) {
                asks[index] = tempAsks[j];
                ++index;
            }
        }
    }

    function getBidsLength(
        address _nftToken,
        address _quoteToken,
        uint256 _tokenId
    ) external view returns (uint256) {
        return tokenBids[_nftToken][_quoteToken][_tokenId].length;
    }

    function getBids(
        address _nftToken,
        address _quoteToken,
        uint256 _tokenId
    ) external view returns (BidEntry[] memory) {
        return tokenBids[_nftToken][_quoteToken][_tokenId];
    }

    function getUserBids(
        address _nftToken,
        address _quoteToken,
        address _user
    ) public view returns (UserBidEntry[] memory) {
        uint256 length = _userBids[_nftToken][_quoteToken][_user].length();
        UserBidEntry[] memory bids = new UserBidEntry[](length);
        for (uint256 i = 0; i < length; i++) {
            (uint256 tokenId, uint256 price) = _userBids[_nftToken][_quoteToken][_user].at(i);
            bids[i] = UserBidEntry({tokenId: tokenId, price: price});
        }
        return bids;
    }

    function getUserBidsByNFT(address _nftToken, address _user)
        external
        view
        returns (
            address[] memory quotes,
            uint256[] memory lengths,
            UserBidEntry[] memory bids
        )
    {
        quotes = getNftQuotes(_nftToken);
        lengths = new uint256[](quotes.length);
        uint256 total = 0;
        for (uint256 i = 0; i < quotes.length; ++i) {
            lengths[i] = _userBids[_nftToken][quotes[i]][_user].length();
            total = total + lengths[i];
        }
        bids = new UserBidEntry[](total);
        uint256 index = 0;
        for (uint256 i = 0; i < quotes.length; ++i) {
            UserBidEntry[] memory tempBids = getUserBids(_nftToken, quotes[i], _user);
            for (uint256 j = 0; j < tempBids.length; ++j) {
                bids[index] = tempBids[j];
                ++index;
            }
        }
    }
}