//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

/*
What should this do?

1. Be able to add strategy contracts
2. Send funds to those contracts of a certain percentage
    a. Upgradable yes or no?

What will it need?

Constraints
    How frequently strategies can receive funds.
    How much of the funds they can receive.
    Which funds they can receive.
*/

/*
Ecosystem Ideas 

Must be fully decentralized. Meaning more thought needs to go into this to think of potential edge cases, incentive alignments, and ways the system can be manipulated. 
It is of the upmost important that this is the case. Focus on education is critical, how to guides, video tutorials, etc must all be created in order for individuals to be able to participate and learn how the system works.


Whitelisting is done through governance with each holder having an equal vote same with strategies. 
    Min requirement?

Forced Growth. Start slow with local hosting and etherscan
 */

import "openzeppelin/contracts/token/ERC20/IERC20.sol";
import "openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IStrategyHub.sol";

contract StrategyHub is IStrategyHub {
    using SafeERC20 for IERC20;

    error NotAStrategy();
    error StrategyCooldown();
    error AlreadySet();
    error NotOwner();

    //Percentages are done through basic division. So if percentage is 2 this equates to 50%
    mapping(address => uint16) percentages;
    mapping(address => uint256) cooldown;
    mapping(address => bool) strategies;

    address public governance;
    address public owner;
    bool public governanceSet;

    constructor() {
        owner = msg.sender;
    }

    function transferToStrategy(IERC20 _token, address _strategy)
        external
        override
    {
        if (strategies[_strategy] != true) revert NotAStrategy();
        if (cooldown[_strategy] > block.timestamp) revert StrategyCooldown();
        cooldown[_strategy] = block.timestamp + 3 days;
        uint16 percentage = percentages[_strategy];
        uint256 amount = IERC20(_token).balanceOf(address(this)) / percentage;
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

    function setGovernance(address _governance) external {
        if (msg.sender != owner) revert NotOwner();
        if (governanceSet = true) revert AlreadySet();
        governance = _governance;
        governanceSet = true;
    }

    modifier onlyGovernance() {
        require(msg.sender == governance);
        _;
    }
}
