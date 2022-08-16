//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;
import "openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IStrategyHub {
    event StrategyAdded(address indexed _strategy);
    event PercentageChanged(address indexed _strategy, uint16 _percentage);
    event StrategyRemoved(address indexed _strategy);

    function transferToStrategy(IERC20 _token, address _strategy) external;

    function updatePercentage(uint16 _percentage, address _destinationContract)
        external;

    function addStrategies(address _strategy) external;

    function removeStrategy(address _strategy) external;
}
