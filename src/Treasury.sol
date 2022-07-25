//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IMugen.sol";
import "openzeppelin/contracts/token/ERC20/IERC20.sol";
import "openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/AggregatorV3Interface.sol";

contract Treasury is Ownable {
    IMugen public Mugen;
    address public treasury;

    mapping(IERC20 => bool) public depositableTokens;
    mapping(IERC20 => AggregatorV3Interface) public priceFeeds;

    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    uint256 internal valueDeposited;
    uint256 internal tokenMintPrice;

    error NotDepositable();

    event Deposit(
        address indexed depositor,
        IERC20 indexed token,
        uint256 valueOfDeposit
    );
    event DepositableToken(IERC20 indexed token, address indexed PriceFeed);

    constructor(address _mugen, address _treasury) {
        Mugen = IMugen(_mugen);
        treasury = _treasury;
    }

    modifier depositable(IERC20 _token) {
        if (depositableTokens[_token] != true) revert NotDepositable();
        _;
    }

    function deposit(IERC20 _token, uint256 _amount)
        external
        depositable(_token)
    {
        require(_amount > 0, "Deposit must be more than 0");
        if (tokenMintPrice == 0) {
            tokenMintPrice += 100 * 1e18;
        }
        uint256 value = usdPrice(_token).mul(_amount).div(
            tokenMintPrice.div(1e18)
        );
        valueDeposited += value;
        tokenMintPrice += value.div(1e3);
        emit Deposit(msg.sender, _token, value);
        IERC20(_token).safeTransferFrom(msg.sender, treasury, _amount);
        Mugen.mint(msg.sender, value);
    }

    //checked
    function addTokenInfo(IERC20 _token, address _pricefeed)
        external
        onlyOwner
    {
        priceFeeds[_token] = AggregatorV3Interface(_pricefeed);
        depositableTokens[_token] = true;
        emit DepositableToken(_token, _pricefeed);
    }

    //checked
    function removeTokenInfo(IERC20 _token) external onlyOwner {
        delete depositableTokens[_token];
        delete priceFeeds[_token];
    }

    /**************************/
    /*** Internal Functions ***/
    /**************************/

    //checked
    function readValue() public view returns (uint256) {
        return valueDeposited;
    }

    //checked
    function readPrice() external view returns (uint256) {
        return tokenMintPrice;
    }

    //checked
    function getPrice(IERC20 _token) public view returns (uint256) {
        (, int256 price, , , ) = priceFeeds[_token].latestRoundData();
        return uint256(price);
    }

    //checked
    function usdPrice(IERC20 _token) public view returns (uint256) {
        uint256 tokenPrice = getPrice(_token);
        uint256 tokenUsdPrice = tokenPrice.div(1e8);
        return tokenUsdPrice;
    }

    //checked
    function checkDepositable(IERC20 _token) external view returns (bool) {
        return depositableTokens[_token];
    }
}
