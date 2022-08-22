//SPDX-License-Identifier: MIT

//Finish this today.
/**
 * What all does this need to do?
 * Receive funds and send them where they should go
 * Determine what percentage goes where
 * add and remove strategies
 * add and remove governors
 * set up multi sig aspect.
 */

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IStrategyHub.sol";

contract StrategyHub is IStrategyHub {
    using SafeERC20 for IERC20;

    error NotAStrategy();
    error StrategyCooldown();
    error AlreadySet();
    error NotOwner();

    mapping(address => uint16) percentages;
    mapping(address => uint256) cooldown;
    mapping(address => bool) strategies;
    mapping(address => mapping(IERC20 => bool)) acceptableTokens;
    mapping(address => bool) governance;

    address public owner;
    bool public governanceSet;

    constructor() {
        owner = msg.sender;
    }

    function transferToStrategy(IERC20 _token, address _strategy)
        external
        override
        acceptableTransfer(_strategy, _token)
    {
        if (strategies[_strategy] != true) revert NotAStrategy();
        if (cooldown[_strategy] > block.timestamp) revert StrategyCooldown();
        cooldown[_strategy] = block.timestamp + 2 days;
        uint16 percentage = percentages[_strategy];
        uint256 amount = (IERC20(_token).balanceOf(address(this)) *
            percentage) / 1000;
        IERC20(_token).safeTransferFrom(address(this), _strategy, amount);
    }

    function updatePercentage(uint16 _percentage, address _destinationContract)
        external
        override
        onlyGovernance
    {
        percentages[_destinationContract] = _percentage;
        emit PercentageChanged(_destinationContract, _percentage);
    }

    function addStrategies(address _strategy) external override onlyGovernance {
        strategies[_strategy] = true;
        emit StrategyAdded(_strategy);
    }

    function removeStrategy(address _strategy)
        external
        override
        onlyGovernance
    {
        delete strategies[_strategy];
        delete percentages[_strategy];
        emit StrategyRemoved(_strategy);
    }

    function addGovernors(address _governor) external {
        if (msg.sender != owner) revert NotOwner();
        governance[_governor] = true;
    }

    function removeGovernors(address _governor) external {
        if (msg.sender != owner) revert NotOwner();
        delete governance[_governor];
    }

    modifier onlyGovernance() {
        if (msg.sender != owner || governance[msg.sender] != true)
            revert NotOwner();
        _;
    }
    modifier acceptableTransfer(address _strategy, IERC20 _token) {
        require(acceptableTokens[_strategy][_token] = true);
        _;
    }
}
