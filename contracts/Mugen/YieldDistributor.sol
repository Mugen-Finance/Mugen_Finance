//SPDX-License-Identifier:MIT

//Need to make theIERC4626 interface

pragma solidity 0.8.7;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC4626} from "../interfaces/IERC4626.sol";

contract YieldDistributor is Ownable {
    using SafeERC20 for IERC20;

    address stakingContract;

    error RewardsToHigh();
    error RewardsToLow();
    error AdminRemoved();

    address public immutable weth;
    address public immutable teamfund;
    address public administrator;
    bool public adminRemoved = false;

    event RewardsDistributed(address indexed _caller, uint256 _rewards);
    event TeamPaid(address indexed _caller, uint256 _teamPercent);

    constructor(address _teamFund, address _weth) {
        teamfund = _teamFund;
        weth = _weth;
        administrator = msg.sender;
    }

    function transferRewards() external payable {
        require(address(stakingContract) != address(0), "staking contract not set");
        if (IERC20(weth).balanceOf(address(this)) < 5 * 1e18) {
            revert RewardsToLow();
        }
        (uint256 team, uint256 reward) = calculateRewards();
        ERC20(weth).approve(address(stakingContract), reward);
        IERC20(weth).safeTransfer(teamfund, team);
        IERC4626(stakingContract).issuanceRate(reward);
        emit RewardsDistributed(msg.sender, reward);
        emit TeamPaid(msg.sender, team);
    }

    function calculateRewards() internal view returns (uint256, uint256) {
        uint256 currentRewards = IERC20(weth).balanceOf(address(this));
        uint256 teamPercent = (currentRewards * 100) / 1000;
        uint256 rewards = (currentRewards * 900) / 1000;
        if (teamPercent + rewards > IERC20(weth).balanceOf(address(this))) {
            revert RewardsToHigh();
        }
        return (teamPercent, rewards);
    }

    function setStaking(address _address) external onlyOwners {
        stakingContract = _address;
    }

    function setAdministrator(address newAdmin) external onlyOwners {
        if (adminRemoved != false) {
            revert AdminRemoved();
        }
        administrator = newAdmin;
    }

    function removeAdmin() external onlyOwner {
        administrator = address(0);
        adminRemoved = true;
    }

    modifier onlyOwners() {
        require(msg.sender == owner() || msg.sender == administrator, "not the owner");
        _;
    }
}
