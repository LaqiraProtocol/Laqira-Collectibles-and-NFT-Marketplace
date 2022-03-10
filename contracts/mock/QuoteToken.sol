// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract QuoteToken is ERC20 {
    constructor(string memory _name, string memory _symbol, uint256 _initialSupply) ERC20(_name, _symbol) {
        mint(msg.sender, _initialSupply);
    }

    function mint(address _to, uint256 _amount) public {
        _mint(_to, _amount);
    }
}