//SPDX-License-Identifier:MIT

pragma solidity 0.8.7;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC4626} from "../interfaces/IERC4626.sol";

contract YieldDistributor is Ownable {
    using SafeERC20 for IERC20;

    /*///////////////////////////////////////////////////////////////
                               Errors
    //////////////////////////////////////////////////////////////*/

    error RewardsToHigh();
    error RewardsToLow();
    error AdminRemoved();

    /*///////////////////////////////////////////////////////////////
                        Immutable Variables
    //////////////////////////////////////////////////////////////*/

    address public immutable weth;
    address public immutable teamfund;

    /*///////////////////////////////////////////////////////////////
                        State Variables
    //////////////////////////////////////////////////////////////*/
    address public administrator;
    bool public adminRemoved = false;
    address public stakingContract;

    /*///////////////////////////////////////////////////////////////
                        Events Variables
    //////////////////////////////////////////////////////////////*/

    event RewardsDistributed(address indexed _caller, uint256 _rewards);
    event TeamPaid(address indexed _caller, uint256 _teamPercent);

    constructor(address _teamFund, address _weth) {
        teamfund = _teamFund;
        weth = _weth;
        administrator = msg.sender;
    }

    /*///////////////////////////////////////////////////////////////
                           User Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice sends rewards to the staking contract and team fund
     */

    function transferRewards() external {
        require(
            address(stakingContract) != address(0),
            "staking contract not set"
        );
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

    /*///////////////////////////////////////////////////////////////
                        Internal Functions
    //////////////////////////////////////////////////////////////*/

    ///@notice calaculates rewards for the staking contract and team

    function calculateRewards() internal view returns (uint256, uint256) {
        uint256 currentRewards = IERC20(weth).balanceOf(address(this));
        uint256 teamPercent = (currentRewards * 100) / 1000;
        uint256 rewards = (currentRewards * 900) / 1000;
        return (teamPercent, rewards);
    }

    /*///////////////////////////////////////////////////////////////
                        Admin Functions
    //////////////////////////////////////////////////////////////*/

    ///@notice sets the staking contract

    function setStaking(address _address) external onlyOwners {
        stakingContract = _address;
    }

    ///@notice sets the administrator for high level access

    function setAdministrator(address newAdmin) external onlyOwners {
        if (adminRemoved != false) {
            revert AdminRemoved();
        }
        administrator = newAdmin;
    }

    ///@notice removes the admins control, once done can not be undone

    function removeAdmin() external onlyOwner {
        administrator = address(0);
        adminRemoved = true;
    }

    /*///////////////////////////////////////////////////////////////
                        Modifier Functions
    //////////////////////////////////////////////////////////////*/

    modifier onlyOwners() {
        require(
            msg.sender == owner() || msg.sender == administrator,
            "not the owner"
        );
        _;
    }
}
