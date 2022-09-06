//SPDX-License-Identifier: MIT

/**
 * Percentages
 * View Functions(contracts in the array and percentage for each contract);
 * Removing and adding to arrays
 */

pragma solidity 0.8.7;

import {IERC20} from "openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IStrategyHub} from "../interfaces/IStrategyHub.sol";
import {Ownable} from "openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "openzeppelin/contracts/security/ReentrancyGuard.sol";

contract StrategyHub is IStrategyHub, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    event USDCTransfer(address indexed _caller, address _usdc, uint256 _amount);
    event WETHTransfer(address indexed _caller, address _weth, uint256 _amount);
    event DAITransfer(address indexed _caller, address _dai, uint256 _amount);
    event FRAXTransfer(address indexed _caller, address _frax, uint256 _amount);

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

    mapping(address => uint16) usdcPercentages;
    mapping(address => uint16) wethPercentages;
    mapping(address => uint16) fraxPercentages;
    mapping(address => uint16) daiPercentages;
    mapping(address => uint256) cooldown;
    mapping(address => bool) strategies;
    mapping(address => mapping(IERC20 => bool)) acceptableTokens;

    /*///////////////////////////////////////////////////////////////
                                 Constants
    //////////////////////////////////////////////////////////////*/

    address public constant USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address public constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public constant DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
    address public constant FRAX = 0x17FC002b466eEc40DaE837Fc4bE5c67993ddBd6F;

    /*///////////////////////////////////////////////////////////////
                                 Arrays
    //////////////////////////////////////////////////////////////*/

    address[] public usdcStrats;
    address[] public wethStrats;
    address[] public daiStrats;
    address[] public fraxStrats;

    /*///////////////////////////////////////////////////////////////
                                 State Variables
    //////////////////////////////////////////////////////////////*/

    address public administrator;
    bool public adminRemoved;
    uint256 public usdcStrategyCooldown;
    uint256 public fraxStrategyCooldown;
    uint256 public wethStrategyCooldown;
    uint256 public daiStrategyCooldown;

    constructor() {
        administrator = msg.sender;
    }

    /*///////////////////////////////////////////////////////////////
                            User  Strategies 
    //////////////////////////////////////////////////////////////*/

    function transferUSDCToStrategy() external nonReentrant {
        require(block.timestamp > usdcStrategyCooldown, "Cannot call yet");
        usdcStrategyCooldown = block.timestamp + 1 days;
        uint256 balance = IERC20(USDC).balanceOf(address(this));
        require(balance > 0, "Balance must be more than zero");
        uint256 totalPercentage;
        for (uint256 i = 0; i < usdcStrats.length; i++) {
            address _to = usdcStrats[i];
            uint256 assetBalance = (balance * usdcPercentages[_to]) / 1000;
            if (assetBalance > 0) {
                IERC20(USDC).transfer(_to, assetBalance);
            }
            totalPercentage += usdcPercentages[_to];
            emit USDCTransfer(msg.sender, USDC, assetBalance);
        }
        require(totalPercentage == 1000, "Incorrect Accounting");
    }

    function transferWETHToStrategy() external nonReentrant {
        require(block.timestamp > wethStrategyCooldown, "Cannot call yet");
        wethStrategyCooldown = block.timestamp + 1 days;
        uint256 balance = IERC20(WETH).balanceOf(address(this));
        require(balance > 0, "Balance must be more than zero");
        uint256 totalPercentage;
        for (uint256 i = 0; i < wethStrats.length; i++) {
            address _to = wethStrats[i];
            uint256 assetBalance = (balance * wethPercentages[_to]) / 1000;
            if (assetBalance > 0) {
                IERC20(WETH).transfer(_to, assetBalance);
            }
            totalPercentage += wethPercentages[_to];
            emit WETHTransfer(msg.sender, WETH, assetBalance);
        }
        require(totalPercentage == 1000, "Incorrect Accounting");
    }

    function transferDAIToStrategy() external nonReentrant {
        require(block.timestamp > daiStrategyCooldown, "Cannot call yet");
        daiStrategyCooldown = block.timestamp + 1 days;
        uint256 balance = IERC20(DAI).balanceOf(address(this));
        require(balance > 0, "Balance must be more than zero");
        uint256 totalPercentage;
        for (uint256 i = 0; i < daiStrats.length; i++) {
            address _to = daiStrats[i];
            uint256 assetBalance = (balance * daiPercentages[_to]) / 1000;
            if (assetBalance > 0) {
                IERC20(DAI).transfer(_to, assetBalance);
            }
            totalPercentage += daiPercentages[_to];
            emit DAITransfer(msg.sender, DAI, assetBalance);
        }
        require(totalPercentage == 1000, "Incorrect Accounting");
    }

    function transferFRAXToStrategy() external nonReentrant {
        require(block.timestamp > fraxStrategyCooldown, "Cannot call yet");
        fraxStrategyCooldown = block.timestamp + 1 days;
        uint256 balance = IERC20(FRAX).balanceOf(address(this));
        require(balance > 0, "Balance must be more than zero");
        uint256 totalPercentage;
        for (uint256 i = 0; i < fraxStrats.length; i++) {
            address _to = fraxStrats[i];
            uint256 assetBalance = (balance * fraxPercentages[_to]) / 1000;
            if (assetBalance > 0) {
                IERC20(FRAX).transfer(_to, assetBalance);
            }
            totalPercentage += fraxPercentages[_to];
            emit DAITransfer(msg.sender, FRAX, assetBalance);
        }
        require(totalPercentage == 1000, "Incorrect Accounting");
    }

    /*///////////////////////////////////////////////////////////////
                                 Strategy Functions 
    //////////////////////////////////////////////////////////////*/

    function addUSDCStrategies(address _strategy, uint16 _percentage)
        external
        onlyOwnerOrAdmin
    {
        require(usdcStrats.length < 5, "Array Maxed Out");
        usdcStrats.push(_strategy);
        usdcPercentages[_strategy] = _percentage;
    }

    function updateUSDCPercentage(address _strategy, uint16 _percentage)
        external
        onlyOwnerOrAdmin
    {
        usdcPercentages[_strategy] = _percentage;
    }

    function addWETHStrategies(address _strategy, uint16 _percentage)
        external
        onlyOwnerOrAdmin
    {
        require(wethStrats.length < 5, "Array Maxed Out");
        wethStrats.push(_strategy);
        wethPercentages[_strategy] = _percentage;
    }

    function updateWETHPercentage(address _strategy, uint16 _percentage)
        external
        onlyOwnerOrAdmin
    {
        wethPercentages[_strategy] = _percentage;
    }

    function addDAIStrategies(address _strategy, uint16 _percentage)
        external
        onlyOwnerOrAdmin
    {
        require(daiStrats.length < 5, "Array Maxed Out");
        daiStrats.push(_strategy);
        daiPercentages[_strategy] = _percentage;
    }

    function updateDAIPercentage(address _strategy, uint16 _percentage)
        external
        onlyOwnerOrAdmin
    {
        daiPercentages[_strategy] = _percentage;
    }

    function addFRAXStrategies(address _strategy, uint16 _percentage)
        external
        onlyOwnerOrAdmin
    {
        require(fraxStrats.length < 5, "Array Maxed Out");
        fraxStrats.push(_strategy);
        fraxPercentages[_strategy] = _percentage;
    }

    function updateFRAXPercentage(address _strategy, uint16 _percentage)
        external
        onlyOwnerOrAdmin
    {
        fraxPercentages[_strategy] = _percentage;
    }

    /**
     * @notice removes the strategy and percentage associated with it
     * @param _strategy address of the strategy being removed
     */
    function removeStrategy(address _strategy) external onlyOwnerOrAdmin {
        delete strategies[_strategy];
        //delete percentages[_strategy];
        emit StrategyRemoved(_strategy);
    }

    /*///////////////////////////////////////////////////////////////
                                 Admin Functions 
    //////////////////////////////////////////////////////////////*/

    ///@notice changes the admin
    function changeAdmin(address _administrator) external onlyOwnerOrAdmin {
        require(adminRemoved == false, "admin removed");
        administrator = _administrator;
    }

    ///@notice removes current admin, sets it to the zero address
    ///and does not allow a new one to be set

    function removeAdmin() external onlyOwner {
        administrator = address(0);
        adminRemoved = true;
    }

    /*///////////////////////////////////////////////////////////////
                                 View Functions 
    //////////////////////////////////////////////////////////////*/

    function checkCooldown(address _strategy) external view returns (uint256) {
        uint256 time = cooldown[_strategy];
        return time;
    }

    function viewWETHPercentages(address _strategy)
        external
        view
        returns (uint16)
    {
        return wethPercentages[_strategy];
    }

    function viewWETHStrategies() external view returns (address[] memory) {
        return wethStrats;
    }

    function viewDAIPercentages(address _strategy)
        external
        view
        returns (uint16)
    {
        return daiPercentages[_strategy];
    }

    function viewDAIStrategies() external view returns (address[] memory) {
        return daiStrats;
    }

    function viewFRAXPercentages(address _strategy)
        external
        view
        returns (uint16)
    {
        return fraxPercentages[_strategy];
    }

    function viewFRAXStrategies() external view returns (address[] memory) {
        return fraxStrats;
    }

    function viewUSDCPercentages(address _strategy)
        external
        view
        returns (uint16)
    {
        return usdcPercentages[_strategy];
    }

    function viewUSDCStrategies() external view returns (address[] memory) {
        return usdcStrats;
    }

    /*///////////////////////////////////////////////////////////////
                                 Modifier Functions 
    //////////////////////////////////////////////////////////////*/

    modifier acceptableTransfer(address _strategy, IERC20 _token) {
        if (acceptableTokens[_strategy][_token] != true) {
            revert NotAStrategy();
        }
        _;
    }

    modifier onlyOwnerOrAdmin() {
        require(
            msg.sender == owner() || msg.sender == administrator,
            "Not Owner"
        );
        _;
    }
}
