// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ICapUSDCReward {
    function collectReward() external;

    function getClaimableReward() external view returns (uint256);
}

interface ICapStrategy {
    function deposit(uint256 amount) external payable;

    function withdraw(uint256 currencyAmount) external;
}
