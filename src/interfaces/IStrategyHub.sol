//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IStrategyHub {
    event StrategyAdded(address indexed _strategy);
    event PercentageChanged(address indexed _strategy, uint16 _percentage);
    event StrategyRemoved(address indexed _strategy);
    event TransferableToken(address indexed _strategy, IERC20 _token);
    event TransferToStrategy(
        address indexed _strategy,
        IERC20 _token,
        uint256 amount
    );
}
