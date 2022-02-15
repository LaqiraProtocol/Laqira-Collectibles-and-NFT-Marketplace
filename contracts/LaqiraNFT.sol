// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract LaqiraNFT is ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    uint256 private mintingFee;

    mapping(uint256 => string) private _tokenURIs;
    mapping(address => uint256[]) private _userPendingIds;
    mapping(uint256 => PendingIds) private _pendingIds;
    mapping(address => uint256[]) private _userRejectedIds;
    mapping(uint256 => PendingIds) private _rejectedIds;

    struct PendingIds {
        address owner;
        string tokenURI;
    }

    uint256[] private pendingRequests;
    uint256[] private rejectedRequests;
    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {
        
    }

    function mint(string memory _tokenURI) public payable {
        uint256 transferredAmount = msg.value;
        
        require(transferredAmount >= mintingFee, 'Insufficient paid amount');

        _tokenIds.increment();

        uint256 newTokenId = _tokenIds.current();

        pendingRequests.push(newTokenId);
        _pendingIds[newTokenId].owner = _msgSender();
        _pendingIds[newTokenId].tokenURI = _tokenURI;
        _userPendingIds[_msgSender()].push(newTokenId);
    }

    function burn(uint256 tokenId) public onlyOwner {
       _burn(tokenId);
    }

    function confirmNFT(uint256 _tokenId) public onlyOwner {
        _mint(_pendingIds[_tokenId].owner, _tokenId);

        _setTokenURI(_tokenId, _pendingIds[_tokenId].tokenURI);

        delUintFromArray(_tokenId, pendingRequests);
        delUintFromArray(_tokenId, _userPendingIds[_pendingIds[_tokenId].owner]);
        delete _pendingIds[_tokenId];
    }

    function rejectNFT(uint256 _tokenId) public onlyOwner {
        _rejectedIds[_tokenId].owner = _pendingIds[_tokenId].owner;
        _rejectedIds[_tokenId].tokenURI = _pendingIds[_tokenId].tokenURI;
        _userRejectedIds[_pendingIds[_tokenId].owner].push(_tokenId);
        rejectedRequests.push(_tokenId);
        delUintFromArray(_tokenId, pendingRequests);
        delUintFromArray(_tokenId, _userPendingIds[_pendingIds[_tokenId].owner]);
        delete _pendingIds[_tokenId];
    }

    function setMintingFeeAmount(uint256 _amount) public onlyOwner {
        mintingFee = _amount;
    }

    function getPendingRequests() public view returns (uint256[] memory) {
        return pendingRequests;
    }

    function getUserPendingIds(address _user) public view returns (uint[] memory) {
        return _userPendingIds[_user];
    }

    function getUserRejectedIds(address _user) public view returns (uint[] memory) {
        return _userRejectedIds[_user];
    }

    function _baseURI() internal view override returns (string memory) {
        return "ipfs://";
    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal {
        require(_exists(tokenId), "URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    function delUintFromArray(
        uint256 _element,
        uint256[] storage array
    ) internal {
        // delete the element
        uint256 len = array.length;
        uint256 j = 0;
        for (uint256 i = 0; i < len - 1; i++) {
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