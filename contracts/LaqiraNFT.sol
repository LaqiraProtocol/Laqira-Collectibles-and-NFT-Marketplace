// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract LaqiraNFT is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    uint256 private mintingFee;

    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {
        
    }

    function _baseURI() internal view override returns (string memory) {
        return "ipfs://";
    }

    function mint(string memory _tokenURI) public payable {
        uint256 transferredAmount = msg.value;
        
        require(transferredAmount >= mintingFee, '');

        _tokenIds.increment();
        
        uint256 newTokenId = _tokenIds.current();

        _mint(_msgSender(), newTokenId);

        _setTokenURI(newTokenId, _tokenURI);
    }

    function setMintingFeeAmount(uint256 _amount) public onlyOwner {
        mintingFee = _amount;       
    }
}