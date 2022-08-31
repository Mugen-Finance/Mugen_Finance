//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IStrategyHub} from "../interfaces/IStrategyHub.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract StrategyHub is IStrategyHub, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*///////////////////////////////////////////////////////////////
                                 Errors
    //////////////////////////////////////////////////////////////*/

    error NotAStrategy();
    error StrategyCooldown();
    error NotOwner();
    error AllowanceFailed();

    /*///////////////////////////////////////////////////////////////
                                 Mappings
    //////////////////////////////////////////////////////////////*/

    mapping(address => uint16) percentages;
    mapping(address => uint256) cooldown;
    mapping(address => bool) strategies;
    mapping(address => mapping(IERC20 => bool)) acceptableTokens;

    /*///////////////////////////////////////////////////////////////
                                 State Variables
    //////////////////////////////////////////////////////////////*/

    address public administrator;
    bool public adminRemoved;

    constructor() {
        administrator = msg.sender;
    }

    /*///////////////////////////////////////////////////////////////
                            User  Strategies 
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice transfers tokens to selected strategies
     * @param _token IERC20 to be sent to the strategy
     * @param _strategy address of the strategy
     * @dev percentage and acceptable tokens need to be specified before hand
     */

    function transferToStrategy(IERC20 _token, address _strategy)
        external
        override
        acceptableTransfer(_strategy, _token)
        nonReentrant
    {
        if (strategies[_strategy] != true) {
            revert NotAStrategy();
        }
        if (cooldown[_strategy] > block.timestamp) {
            revert StrategyCooldown();
        }
        cooldown[_strategy] = block.timestamp + 2 days;
        uint16 percentage = percentages[_strategy];
        uint256 amount = (IERC20(_token).balanceOf(address(this)) *
            percentage) / 1000;

        IERC20(_token).safeTransfer(_strategy, amount);
        emit TransferToStrategy(_strategy, _token, amount);
    }

    /*///////////////////////////////////////////////////////////////
                                 Admin Functions 
    //////////////////////////////////////////////////////////////*/

    /**
     * @param _percentage percentage to the decicated strategy
     * @param _destinationContract strategy to be given the specified percentage
     * @dev percentages are calculted using x / 1000
     */

    function updatePercentage(uint16 _percentage, address _destinationContract)
        external
        override
        onlyOwners
    {
        require(_percentage > 0 && _percentage <= 1000, "Invalid Percentages");
        percentages[_destinationContract] = _percentage;
        emit PercentageChanged(_destinationContract, _percentage);
    }

    ///@param _strategy contract address of prebuilt strategy

    function addStrategies(address _strategy) external override onlyOwners {
        strategies[_strategy] = true;
        emit StrategyAdded(_strategy);
    }

    /**
     * @notice removes the strategy and percentage associated with it
     * @param _strategy address of the strategy being removed
     */
    function removeStrategy(address _strategy) external override onlyOwners {
        delete strategies[_strategy];
        delete percentages[_strategy];
        emit StrategyRemoved(_strategy);
    }

    function addTransferableTokens(address _strategy, IERC20 _token)
        external
        onlyOwners
    {
        acceptableTokens[_strategy][_token] = true;
        emit TransferableToken(_strategy, _token);
    }

    function removeTransferableTokens(address _strategy, IERC20 _token)
        external
        onlyOwners
    {
        acceptableTokens[_strategy][_token] = false;
    }

    function changeAdmin(address _administrator) external onlyOwners {
        require(adminRemoved == false, "admin removed");
        administrator = _administrator;
    }

    function removeAdmin() external onlyOwner {
        administrator = address(0);
    }

    /*///////////////////////////////////////////////////////////////
                                 View Functions 
    //////////////////////////////////////////////////////////////*/

    function checkCooldown(address _strategy) external view returns (uint256) {
        uint256 time = cooldown[_strategy];
        return time;
    }

    modifier acceptableTransfer(address _strategy, IERC20 _token) {
        if (acceptableTokens[_strategy][_token] != true) {
            revert NotAStrategy();
        }
        _;
    }

    modifier onlyOwners() {
        require(
            msg.sender == owner() || msg.sender == administrator,
            "Not Owner"
        );
        _;
    }
}
