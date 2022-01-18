// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0;

interface IExchangeNFTs {
    event Ask(
        address indexed nftToken,
        address seller,
        uint256 indexed tokenId,
        address indexed quoteToken,
        uint256 price
    );
    event Trade(
        address indexed nftToken,
        address indexed quoteToken,
        address seller,
        address buyer,
        uint256 indexed tokenId,
        uint256 originPrice,
        uint256 price,
        uint256 fee
    );
    event CancelSellToken(
        address indexed nftToken,
        address indexed quoteToken,
        address seller,
        uint256 indexed tokenId,
        uint256 price
    );
    event Bid(
        address indexed nftToken,
        address bidder,
        uint256 indexed tokenId,
        address indexed quoteToken,
        uint256 price
    );
    event CancelBidToken(
        address indexed nftToken,
        address indexed quoteToken,
        address bidder,
        uint256 indexed tokenId,
        uint256 price
    );

    function getNftQuotes(address _nftToken) external view returns (address[] memory);

    function batchReadyToSellToken(
        address[] memory _nftTokens,
        uint256[] memory _tokenIds,
        address[] memory _quoteTokens,
        uint256[] memory _prices,
        uint256[] memory _selleStatus
    ) external;

    function batchReadyToSellTokenTo(
        address[] memory _nftTokens,
        uint256[] memory _tokenIds,
        address[] memory _quoteTokens,
        uint256[] memory _prices,
        uint256[] memory _selleStatus,
        address _to
    ) external;

    function readyToSellToken(
        address _nftToken,
        uint256 _tokenId,
        address _quoteToken,
        uint256 _price,
        uint256 _selleStatus
    ) external;

    function readyToSellToken(
        address _nftToken,
        uint256 _tokenId,
        address _quoteToken,
        uint256 _price
    ) external;

    function readyToSellTokenTo(
        address _nftToken,
        uint256 _tokenId,
        address _quoteToken,
        uint256 _price,
        address _to,
        uint256 _selleStatus
    ) external;

    function batchSetCurrentPrice(
        address[] memory _nftTokens,
        uint256[] memory _tokenIds,
        address[] memory _quoteTokens,
        uint256[] memory _prices
    ) external;

    function setCurrentPrice(
        address _nftToken,
        uint256 _tokenId,
        address _quoteToken,
        uint256 _price
    ) external;

    function batchBuyToken(
        address[] memory _nftTokens,
        uint256[] memory _tokenIds,
        address[] memory _quoteTokens,
        uint256[] memory _prices
    ) external;

    function batchBuyTokenTo(
        address[] memory _nftTokens,
        uint256[] memory _tokenIds,
        address[] memory _quoteTokens,
        uint256[] memory _prices,
        address _to
    ) external;

    function buyToken(
        address _nftToken,
        uint256 _tokenId,
        address _quoteToken,
        uint256 _price
    ) external payable;

    function buyTokenTo(
        address _nftToken,
        uint256 _tokenId,
        address _quoteToken,
        uint256 _price,
        address _to
    ) external payable;

    function batchCancelSellToken(address[] memory _nftTokens, uint256[] memory _tokenIds) external;

    function cancelSellToken(address _nftToken, uint256 _tokenId) external;

    function batchBidToken(
        address[] memory _nftTokens,
        uint256[] memory _tokenIds,
        address[] memory _quoteTokens,
        uint256[] memory _prices
    ) external;

    function batchBidTokenTo(
        address[] memory _nftTokens,
        uint256[] memory _tokenIds,
        address[] memory _quoteTokens,
        uint256[] memory _prices,
        address _to
    ) external;

    function bidToken(
        address _nftToken,
        uint256 _tokenId,
        address _quoteToken,
        uint256 _price
    ) external payable;

    function bidTokenTo(
        address _nftToken,
        uint256 _tokenId,
        address _quoteToken,
        uint256 _price,
        address _to
    ) external payable;

    function batchUpdateBidPrice(
        address[] memory _nftTokens,
        uint256[] memory _tokenIds,
        address[] memory _quoteTokens,
        uint256[] memory _prices
    ) external;

    function updateBidPrice(
        address _nftToken,
        uint256 _tokenId,
        address _quoteToken,
        uint256 _price
    ) external payable;

    function sellTokenTo(
        address _nftToken,
        uint256 _tokenId,
        address _quoteToken,
        uint256 _price,
        address _to
    ) external;

    function batchCancelBidToken(
        address[] memory _nftTokens,
        address[] memory _quoteTokens,
        uint256[] memory _tokenIds
    ) external;

    function cancelBidToken(
        address _nftToken,
        address _quoteToken,
        uint256 _tokenId
    ) external;
}