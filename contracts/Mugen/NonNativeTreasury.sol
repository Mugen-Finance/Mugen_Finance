//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../interfaces/IMugen.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/ThisThing.sol";
import "./NonblockingLzApp.sol";
import "../interfaces/INonNativeTreasury.sol";

contract NonNativeTreasury is
    NonblockingLzApp,
    ReentrancyGuard,
    INonNativeTreasury
{
    IMugen public immutable mugen;
    address public immutable treasury;
    uint16 public immutable dstChainId;

    mapping(IERC20 => bool) public depositableTokens;
    mapping(IERC20 => ThisThing) public priceFeeds;

    using SafeERC20 for IERC20;

    uint256 public valueDeposited;

    uint256 internal constant VALID_PERIOD = 12 hours;
    uint256 internal constant MIN_VALUE = 100 * 1e18;

    error NotDepositable();
    error NotUpdated();
    error InvalidPrice();
    error TransferFail();
    error InsufficentBalance();
    error InsufficentAllowance();

    constructor(
        address _mugen,
        address _treasury,
        address _endpoint,
        uint16 _dstChainId
    ) NonblockingLzApp(_endpoint) {
        mugen = IMugen(_mugen);
        treasury = _treasury;
        dstChainId = _dstChainId;
    }

    /*************************/
    /****  User Functions ****/
    /*************************/

    function deposit(IERC20Metadata _token, uint256 _amount)
        external
        nonReentrant
        depositable(_token)
    {
        if (IERC20Metadata(_token).decimals() < 18) {
            uint256 dec = 18 - (IERC20Metadata(_token).decimals());
            _amount = _amount * 10**dec;
        }
        require(_amount > 0, "Deposit must be more than 0");
        if (IERC20(_token).balanceOf(msg.sender) < _amount)
            revert InsufficentBalance();
        if (IERC20(_token).allowance(msg.sender, address(this)) < _amount)
            revert InsufficentAllowance();
        uint256 tokenPrice = getPrice(_token);
        uint256 value = (tokenPrice * _amount) /
            10**(priceFeeds[_token].decimals());
        valueDeposited += value;
        require(value >= MIN_VALUE, "less than minimum deposit");
        bytes memory payload = abi.encode(value, msg.sender, _token, _amount);
        uint16 version = 1;
        uint256 gasForDestinationLzReceive = 350000;
        bytes memory adapterParams = abi.encodePacked(
            version,
            gasForDestinationLzReceive
        );
        _lzSend(
            dstChainId,
            payload,
            payable(msg.sender),
            address(0x0),
            adapterParams
        );
        emit Deposit(msg.sender, _token, value);
    }

    /**************************/
    /****  Admin Functions ****/
    /**************************/

    function addTokenInfo(IERC20 _token, address _pricefeed)
        external
        onlyOwner
    {
        priceFeeds[_token] = ThisThing(_pricefeed);
        depositableTokens[_token] = true;
        emit DepositableToken(_token, _pricefeed);
    }

    function removeTokenInfo(IERC20 _token) external onlyOwner {
        delete depositableTokens[_token];
        delete priceFeeds[_token];
        emit TokenRemoved(_token);
    }

    /*************************/
    /****  View Functions ****/
    /*************************/

    function readValue() public view returns (uint256) {
        return valueDeposited;
    }

    function getPrice(IERC20 _token) internal view returns (uint256) {
        (, int256 price, , uint256 updatedAt, ) = priceFeeds[_token]
            .latestRoundData();
        if (block.timestamp - updatedAt > VALID_PERIOD) revert NotUpdated();
        if (price <= 0) revert InvalidPrice();
        return uint256(price);
    }

    function checkDepositable(IERC20 _token) external view returns (bool) {
        return depositableTokens[_token];
    }

    /**************************/
    /*** Modifier Functions ***/
    /**************************/

    modifier depositable(IERC20 _token) {
        if (depositableTokens[_token] != true) revert NotDepositable();
        _;
    }

    /**************************/
    /**** Layer0 Functions ****/
    /**************************/

    function _nonblockingLzReceive(
        uint16,
        bytes memory,
        uint64, /*_nonce*/
        bytes memory _payload
    ) internal override {
        (
            uint256 mintAmount,
            address _depositor,
            IERC20 _token,
            uint256 _amount
        ) = abi.decode(_payload, (uint256, address, IERC20, uint256));
        IERC20(_token).safeTransferFrom(_depositor, address(this), _amount);
        mugen.mint(_depositor, mintAmount);
    }

    receive() external payable {}
}
