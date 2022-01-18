// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0;
pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import './TransferHelper.sol';

library ExchangeNFTsHelper {
    address public constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function burnToken(
        address _token,
        address _from,
        uint256 _amount
    ) internal {
        if (_from == address(this)) {
            ERC20Burnable(_token).burn(_amount);
        } else {
            ERC20Burnable(_token).burnFrom(_from, _amount);
        }
    }

    function transferToken(
        address _token,
        address _from,
        address _to,
        uint256 _amount
    ) internal {
        if (_amount == 0) {
            return;
        }
        if (_token == ExchangeNFTsHelper.ETH_ADDRESS) {
            if (_from == address(this)) {
                TransferHelper.safeTransferETH(_to, _amount);
            } else {
                // transfer by msg.value,  && msg.value == _amount
                require(_from == msg.sender && _to == address(this), 'error eth');
            }
        } else {
            if (_from == address(this)) {
                TransferHelper.safeTransfer(_token, _to, _amount);
            } else {
                TransferHelper.safeTransferFrom(_token, _from, _to, _amount);
            }
        }
    }
}