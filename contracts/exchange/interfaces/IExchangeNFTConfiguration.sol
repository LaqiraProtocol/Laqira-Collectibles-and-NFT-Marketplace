// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0;
pragma experimental ABIEncoderV2;

interface IExchangeNFTConfiguration {
    event FeeAddressTransferred(
        address indexed nftToken,
        address indexed quoteToken,
        address previousOwner,
        address newOwner
    );
    event SetFee(address indexed nftToken, address indexed quoteToken, address seller, uint256 oldFee, uint256 newFee);
    event SetFeeBurnAble(
        address indexed nftToken,
        address indexed quoteToken,
        address seller,
        bool oldFeeBurnable,
        bool newFeeBurnable
    );
    event SetRoyaltiesProvider(
        address indexed nftToken,
        address indexed quoteToken,
        address seller,
        address oldRoyaltiesProvider,
        address newRoyaltiesProvider
    );
    event SetRoyaltiesBurnable(
        address indexed nftToken,
        address indexed quoteToken,
        address seller,
        bool oldRoyaltiesBurnable,
        bool newFeeRoyaltiesBurnable
    );
    event UpdateSettings(uint256 indexed setting, uint256 proviousValue, uint256 value);
    event NFTTradeStatus(address _nftToken, bool _enable);
    event NFTQuoteSet(address _nftToken, address _quote, bool _enable);

    struct NftSettings {
        bool enable;
        bool nftQuoteEnable;
        address feeAddress;
        bool feeBurnAble;
        uint256 feeValue;
        address royaltiesProvider;
        bool royaltiesBurnable;
    }

    function settings(uint256 _key) external view returns (uint256 value);

    function nftEnables(address _nftToken) external view returns (bool enable);

    function nftQuoteEnables(address _nftToken, address _quoteToken) external view returns (bool enable);

    function feeBurnables(address _nftToken, address _quoteToken) external view returns (bool enable);

    function feeAddresses(address _nftToken, address _quoteToken) external view returns (address feeAddress);

    function feeValues(address _nftToken, address _quoteToken) external view returns (uint256 feeValue);

    function royaltiesProviders(address _nftToken, address _quoteToken)
        external
        view
        returns (address royaltiesProvider);

    function royaltiesBurnables(address _nftToken, address _quoteToken) external view returns (bool enable);

    function checkEnableTrade(address _nftToken, address _quoteToken) external view;

    function whenSettings(uint256 key, uint256 value) external view;

    function setSettings(uint256[] memory keys, uint256[] memory values) external;

    function nftSettings(address _nftToken, address _quoteToken) external view returns (NftSettings memory);

    function setNftEnables(address _nftToken, bool _enable) external;

    function setNftQuoteEnables(
        address _nftToken,
        address[] memory _quotes,
        bool _enable
    ) external;

    function getNftQuotes(address _nftToken) external view returns (address[] memory quotes);

    function transferFeeAddress(
        address _nftToken,
        address _quoteToken,
        address _feeAddress
    ) external;

    function batchTransferFeeAddress(
        address _nftToken,
        address[] memory _quoteTokens,
        address[] memory _feeAddresses
    ) external;

    function setFee(
        address _nftToken,
        address _quoteToken,
        uint256 _feeValue
    ) external;

    function batchSetFee(
        address _nftToken,
        address[] memory _quoteTokens,
        uint256[] memory _feeValues
    ) external;

    function setFeeBurnAble(
        address _nftToken,
        address _quoteToken,
        bool _feeBurnable
    ) external;

    function batchSetFeeBurnAble(
        address _nftToken,
        address[] memory _quoteTokens,
        bool[] memory _feeBurnables
    ) external;

    function setRoyaltiesProvider(
        address _nftToken,
        address _quoteToken,
        address _royaltiesProvider
    ) external;

    function batchSetRoyaltiesProviders(
        address _nftToken,
        address[] memory _quoteTokens,
        address[] memory _royaltiesProviders
    ) external;

    function setRoyaltiesBurnable(
        address _nftToken,
        address _quoteToken,
        bool _royaltiesBurnable
    ) external;

    function batchSetRoyaltiesBurnable(
        address _nftToken,
        address[] memory _quoteTokens,
        bool[] memory _royaltiesBurnables
    ) external;

    function addNft(
        address _nftToken,
        bool _enable,
        address[] memory _quotes,
        address[] memory _feeAddresses,
        uint256[] memory _feeValues,
        bool[] memory _feeBurnAbles,
        address[] memory _royaltiesProviders,
        bool[] memory _royaltiesBurnables
    ) external;
}