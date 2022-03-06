// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";

import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

import "./exchange/royalties/IRoyaltiesProvider.sol";

interface IBEP20 {
    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */

    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract LaqiraNFT is ERC721EnumerableUpgradeable, OwnableUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private _tokenIds;
    uint256 private mintingFee;
    address private feeAddress;
    address private royalitiesProviderAddress;

    mapping(uint256 => string) private _tokenURIs;
    mapping(address => uint256[]) private _userPendingIds;
    mapping(uint256 => PendingIds) private _pendingIds;
    mapping(address => uint256[]) private _userRejectedIds;
    mapping(uint256 => PendingIds) private _rejectedIds;

    mapping(address => bool) private operators;

    struct PendingIds {
        address owner;
        string tokenURI;
    }

    uint256[] private pendingRequests;
    uint256[] private rejectedRequests;

    function initialize(string memory _name, string memory _symbol, address feeAddress_, uint256 mintingFee_, address royalitiesProviderAddress_) public initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
        __ERC721Enumerable_init_unchained();
        __ERC721_init_unchained(_name, _symbol);
        __ERC165_init_unchained();
        feeAddress = feeAddress_;
        mintingFee = mintingFee_;
        royalitiesProviderAddress = royalitiesProviderAddress_;
    }

    function mint(string memory _tokenURI, address[] memory royaltyOwners, uint96[] memory values) public virtual payable {
        uint256 transferredAmount = msg.value;
        
        require(transferredAmount >= mintingFee, 'Insufficient paid amount');

        (bool success, ) = feeAddress.call{value: transferredAmount}(new bytes(0));
        require(success, 'Transfer failed');

        _tokenIds.increment();

        uint256 newTokenId = _tokenIds.current();

        pendingRequests.push(newTokenId);
        _pendingIds[newTokenId].owner = _msgSender();
        _pendingIds[newTokenId].tokenURI = _tokenURI;
        _userPendingIds[_msgSender()].push(newTokenId);
        
        IRoyaltiesProvider(royalitiesProviderAddress).setRoyalties(newTokenId, royaltyOwners, values);
    }
    /**
        This function will be used only by owner to revive NFT ids which have been rejected by operator
        or burnt by owner by mistake. 
     */
    function mintTo(uint256 _tokenId) public virtual onlyOwner {
        require(_rejectedIds[_tokenId].owner != address(0), 'NFT should have prior owner');
        pendingRequests.push(_tokenId);
        _pendingIds[_tokenId].owner = _rejectedIds[_tokenId].owner;
        _pendingIds[_tokenId].tokenURI = _rejectedIds[_tokenId].tokenURI;
        _userPendingIds[_rejectedIds[_tokenId].owner].push(_tokenId);

        delUintFromArray(_tokenId, rejectedRequests);
        delUintFromArray(_tokenId, _userRejectedIds[_rejectedIds[_tokenId].owner]);
        delete _rejectedIds[_tokenId];
    }

    function burn(uint256 tokenId) public virtual onlyOwner {
       _rejectedIds[tokenId].owner = ERC721Upgradeable.ownerOf(tokenId);
       _rejectedIds[tokenId].tokenURI = tokenURI(tokenId);
       _userRejectedIds[ERC721Upgradeable.ownerOf(tokenId)].push(tokenId);
       rejectedRequests.push(tokenId);
       _burn(tokenId);
    }

    function confirmNFT(uint256 _tokenId) public virtual {
        require(operators[_msgSender()] || _msgSender() == owner(), 'Permission denied!');
        _mint(_pendingIds[_tokenId].owner, _tokenId);

        _setTokenURI(_tokenId, _pendingIds[_tokenId].tokenURI);

        delUintFromArray(_tokenId, pendingRequests);
        delUintFromArray(_tokenId, _userPendingIds[_pendingIds[_tokenId].owner]);
        delete _pendingIds[_tokenId];
    }

    function rejectNFT(uint256 _tokenId) public virtual {
        require(operators[_msgSender()] || _msgSender() == owner(), 'Permission denied!');
        _rejectedIds[_tokenId].owner = _pendingIds[_tokenId].owner;
        _rejectedIds[_tokenId].tokenURI = _pendingIds[_tokenId].tokenURI;
        _userRejectedIds[_pendingIds[_tokenId].owner].push(_tokenId);
        rejectedRequests.push(_tokenId);
        delUintFromArray(_tokenId, pendingRequests);
        delUintFromArray(_tokenId, _userPendingIds[_pendingIds[_tokenId].owner]);
        delete _pendingIds[_tokenId];
    }

    function setMintingFeeAmount(uint256 _amount) public virtual onlyOwner {
        mintingFee = _amount;
    }

    function setAsOperator(address _operator) public virtual onlyOwner {
        operators[_operator] = true;
    }

    function removeOperator(address _operator) public virtual onlyOwner {
        operators[_operator] = false;
    }

    function transferAnyBEP20(address _tokenAddress, address _to, uint256 _amount) public virtual onlyOwner returns (bool) {
        IBEP20(_tokenAddress).transfer(_to, _amount);
        return true;
    }

    function adminWithdrawal(uint256 _amount) public virtual onlyOwner {
        address payable _owner = payable(owner());
        _owner.transfer(_amount);
    }

    function setFeeAddress(address _newAddress) public virtual onlyOwner {
        feeAddress = _newAddress;
    }

    function transfer(address _to, uint256 _tokenId) public virtual returns (bool) {
        _transfer(_msgSender(), _to, _tokenId);
        return true;
    }

    function setRoyalitiesProviderAddress(address _royalitiesProviderAddress) public virtual onlyOwner {
        royalitiesProviderAddress = _royalitiesProviderAddress;
    }

    function getRoyalitiesProviderAddress() public virtual view returns (address) {
        return royalitiesProviderAddress;
    }

    function getFeeAddress() public virtual view returns (address) {
        return feeAddress;
    }

    function isOperator(address _operator) public virtual view returns (bool) {
        return operators[_operator];
    }

    function getPendingRequests() public virtual view returns (uint256[] memory) {
        return pendingRequests;
    }

    function getRejectedRequests() public virtual view returns (uint256[] memory) {
        return rejectedRequests;
    }

    function getUserPendingIds(address _user) public virtual view returns (uint[] memory) {
        return _userPendingIds[_user];
    }

    function getUserRejectedIds(address _user) public virtual view returns (uint[] memory) {
        return _userRejectedIds[_user];
    }

    function fetchPendingIdDetails(uint256 _id) public virtual view returns (PendingIds memory) {
        return _pendingIds[_id];
    }

    function fetchRejectedIdDetails(uint256 _id) public virtual view returns (PendingIds memory) {
        return _rejectedIds[_id];
    }

    function tokenURI(uint256 tokenId) public virtual view override returns (string memory) {
       return _tokenURIs[tokenId];
    }

    function _baseURI() internal virtual view override returns (string memory) {
        return "ipfs://";
    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        require(_exists(tokenId), "URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    function delUintFromArray(
        uint256 _element,
        uint256[] storage array
    ) internal virtual {
        // delete the element
        uint256 len = array.length;
        uint256 j = 0;
        for (uint256 i = 0; i <= len - 1; i++) {
            if (array[i] == _element) {
                j = i;
                break;
            }
        }
        for (j; j < len - 1; j++) {
            array[j] = array[j + 1];
        }
        array.pop();
    }
}