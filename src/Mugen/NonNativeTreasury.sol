//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IMugen.sol";
import "openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/ThisThing.sol";
import "./NonblockingLzApp.sol";

contract NonNativeTreasury is NonblockingLzApp, ReentrancyGuard {
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

    event Removed(IERC20 indexed _token);
    event Deposit(
        address indexed depositor,
        IERC20 indexed token,
        uint256 valueOfDeposit
    );
    event DepositableToken(IERC20 indexed token, address indexed PriceFeed);

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

    function deposit(IERC20 _token, uint256 _amount)
        external
        nonReentrant
        depositable(_token)
    {
        require(_amount > 0, "Deposit must be more than 0");
        uint256 _value = getValue(_token, _amount);
        valueDeposited += _value;
        require(_value >= MIN_VALUE, "less than minimum deposit");
        bytes memory payload = abi.encode(_value, msg.sender);
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
        emit Deposit(msg.sender, _token, _value);
        IERC20(_token).safeTransferFrom(msg.sender, treasury, _amount);
    }

    /**************************/
    /****  Admin Functions ****/
    /**************************/

    function addTokenInfo(IERC20 _token, address _pricefeed)
        external
        onlyOwner
    {
        require(ThisThing(_pricefeed).decimals() == 8, "wrong decimals");
        priceFeeds[_token] = ThisThing(_pricefeed);
        depositableTokens[_token] = true;
        emit DepositableToken(_token, _pricefeed);
    }

    function removeTokenInfo(IERC20 _token) external onlyOwner {
        delete depositableTokens[_token];
        delete priceFeeds[_token];
        emit Removed(_token);
    }

    /*************************/
    /****  View Functions ****/
    /*************************/

    //Think about the necessity of the tokenMintPrice variable in this function. Can this be abstracted away to the main treasury contract?
    function getValue(IERC20 _token, uint256 _amount)
        internal
        view
        returns (uint256)
    {
        uint256 value = usdPrice(_token) * _amount;
        return value;
    }

    function readValue() public view returns (uint256) {
        return valueDeposited;
    }

    function getPrice(IERC20 _token) public view returns (uint256) {
        (, int256 price, , uint256 updatedAt, ) = priceFeeds[_token]
            .latestRoundData();
        if (block.timestamp - updatedAt > VALID_PERIOD) revert NotUpdated();
        if (price <= 0) revert InvalidPrice();
        return uint256(price);
    }

    function usdPrice(IERC20 _token) public view returns (uint256) {
        uint256 tokenPrice = getPrice(_token);
        uint256 tokenUsdPrice = tokenPrice / 1e8;
        return tokenUsdPrice;
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

    function _nonblockingLzReceive(
        uint16,
        bytes memory,
        uint64, /*_nonce*/
        bytes memory _payload
    ) internal override {
        (uint256 mintAmount, address _depositor) = abi.decode(
            _payload,
            (uint256, address)
        );
        mugen.mint(_depositor, mintAmount);
    }

    receive() external payable {}
}
