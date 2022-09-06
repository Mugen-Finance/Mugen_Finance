//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "openzeppelin/contracts/token/ERC20/IERC20.sol";

interface INonNativeTreasury {
    event Deposit(
        address indexed _depositor,
        IERC20 indexed _token,
        uint256 _value
    );
    event DepositableToken(IERC20 indexed _token, address indexed _priceFreed);
    event TokenRemoved(IERC20 indexed _token);
}
