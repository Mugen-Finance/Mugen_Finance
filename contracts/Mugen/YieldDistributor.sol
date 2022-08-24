//SPDX-License-Identifier:MIT

pragma solidity 0.8.7;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract YieldDistributor {
    using SafeERC20 for IERC20;

    error RewardsToHigh();

    address public immutable weth;
    address public immutable teamfund;
    address public stakingContract;

    event RewardsDistributed(address indexed _caller, uint256 _rewards);
    event TeamPaid(address indexed _caller, uint256 _teamPercent);

    constructor(address _teamFund, address _weth) {
        teamfund = _teamFund;
        weth = _weth;
    }

    function transferRewards() external {
        require(stakingContract != address(0), "staking contract not set");
        uint256 currentRewards = IERC20(weth).balanceOf(address(this));
        uint256 teamPercent = (currentRewards * 100) / 1000;
        uint256 rewards = (currentRewards * 900) / 1000;
        if (teamPercent + rewards > IERC20(weth).balanceOf(address(this)))
            revert RewardsToHigh();
        IERC20(weth).safeTransferFrom(address(this), stakingContract, rewards);
        IERC20(weth).safeTransferFrom(address(this), teamfund, teamPercent);
        emit RewardsDistributed(msg.sender, rewards);
        emit TeamPaid(msg.sender, teamPercent);
    }
}
