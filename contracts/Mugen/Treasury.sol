//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IMugen.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/AggregatorPriceFeeds.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../Bancor/BancorFormula.sol";
import "../interfaces/ITreasury.sol";

contract Treasury is BancorFormula, ITreasury {
    IMugen public immutable mugen;
    address public immutable treasury;

    mapping(IERC20 => bool) public depositableTokens;
    mapping(IERC20 => AggregatorPriceFeeds) public priceFeeds;
    mapping(address => uint16) public layerZeroAddress;

    using SafeERC20 for IERC20;

    uint256 public constant SCALE = 10**18;
    uint256 public reserveBalance = 10 * SCALE;
    uint256 public constant RESERVE_RATIO = 800000;
    uint256 public valueDeposited;
    uint256 public s_totalSupply;
    uint256 internal constant VALID_PERIOD = 12 hours;
    uint256 internal constant MIN_VALUE = 100 * 10**18;
    uint256 private locked = 1;
    address public owner;
    address public Communicator;

    error NotDepositable();
    error NotUpdated();
    error InvalidPrice();
    error NotOwner();
    error NotCommunicator();
    error UnderMinDeposit();

    constructor(address _mugen, address _treasury) {
        mugen = IMugen(_mugen);
        treasury = _treasury;
        s_totalSupply += 1e18;
        owner = msg.sender;
    }

    /**************************/
    /***  Staker Functions ****/
    /**************************/

    function deposit(IERC20Metadata _token, uint256 _amount)
        external
        nonReentrant
        depositable(_token)
    {
        uint256 amount = _amount;
        if (IERC20Metadata(_token).decimals() < 18) {
            uint256 dec = 18 - (IERC20Metadata(_token).decimals());
            amount = _amount * 10**dec;
        }
        require(amount > 0, "Deposit must be more than 0");
        uint256 tokenPrice = getPrice(_token);
        uint256 value = (tokenPrice * amount) /
            10**(priceFeeds[_token].decimals());
        require(value >= MIN_VALUE, "less than min deposit");
        uint256 calculated = _continuousMint(amount);
        s_totalSupply += calculated;
        valueDeposited += value;
        emit Deposit(msg.sender, _token, value);
        IERC20(_token).safeTransferFrom(msg.sender, treasury, _amount);
        mugen.mint(msg.sender, calculated);
    }

    function receiveMessage(uint256 _amount)
        external
        override
        returns (uint256)
    {
        if (msg.sender != Communicator) revert NotCommunicator();
        uint256 test = _continuousMint(_amount);
        s_totalSupply += test;
        return test;
    }

    /**************************/
    /****  Admin Functions ****/
    /**************************/

    function addTokenInfo(IERC20 _token, address _pricefeed) external {
        if (msg.sender != owner) revert NotOwner();
        priceFeeds[_token] = AggregatorPriceFeeds(_pricefeed);
        depositableTokens[_token] = true;
        emit DepositableToken(_token, _pricefeed);
    }

    function removeTokenInfo(IERC20 _token) external {
        if (msg.sender != owner) revert NotOwner();
        delete depositableTokens[_token];
        delete priceFeeds[_token];
        emit TokenRemoved(_token);
    }

    function setCommunicator(address _comms) external {
        if (msg.sender != owner) revert NotOwner();
        Communicator = _comms;
    }

    function setRemotes(uint16 _srcChainId, bytes calldata _srcAddress) public {
        mugen.setTrustedRemote(_srcChainId, _srcAddress);
    }

    /*************************/
    /****  View Functions ****/
    /*************************/

    function getPrice(IERC20 _token) internal view returns (uint256) {
        (, int256 price, , uint256 updatedAt, ) = priceFeeds[_token]
            .latestRoundData();
        if (block.timestamp - updatedAt > VALID_PERIOD) revert NotUpdated();
        if (price <= 0) revert InvalidPrice();
        return uint256(price);
    }

    function readSupply() external view returns (uint256) {
        return s_totalSupply;
    }

    /**************************/
    /*** Modifier Functions ***/
    /**************************/

    modifier nonReentrant() {
        require(locked == 1, "Treasury:LOCKED");

        locked = 2;

        _;

        locked = 1;
    }

    modifier depositable(IERC20 _token) {
        if (depositableTokens[_token] != true) revert NotDepositable();
        _;
    }

    /**************************/
    /**** Bancor Functions ****/
    /**************************/

    function calculateContinuousMintReturn(uint256 _amount)
        public
        view
        returns (uint256 mintAmount)
    {
        return
            purchaseTargetAmount(
                s_totalSupply,
                reserveBalance,
                uint32(RESERVE_RATIO),
                _amount
            );
    }

    function _continuousMint(uint256 _deposit) internal returns (uint256) {
        uint256 amount = calculateContinuousMintReturn(_deposit);
        reserveBalance += _deposit;
        return amount;
    }

    receive() external payable {}
}
