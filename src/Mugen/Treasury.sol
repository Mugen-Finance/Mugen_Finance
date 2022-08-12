//SPDX-License-Identifier: MIT

//TODO: Remove Reserve Token Address Implementations

pragma solidity 0.8.7;

import "./NonblockingLzApp.sol";
import "openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IMugen.sol";
import "openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/ThisThing.sol";
import "openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../../Bancor/BancorFormula.sol";

contract Treasury is NonblockingLzApp, ReentrancyGuard, BancorFormula {
    IMugen public immutable mugen;
    address public immutable treasury;

    mapping(IERC20 => bool) public depositableTokens;
    mapping(IERC20 => ThisThing) public priceFeeds;
    mapping(address => uint16) public layerZeroAddress;

    using SafeERC20 for IERC20;

    uint256 public constant SCALE = 10**18;
    uint256 public reserveBalance = 10 * SCALE;
    uint256 public constant RESERVE_RATIO = 800000;
    uint256 public valueDeposited;
    uint256 public s_totalSupply;
    uint256 internal constant VALID_PERIOD = 12 hours;
    uint256 internal constant MIN_VALUE = 100 * 1e18;

    error NotDepositable();
    error NotUpdated();
    error InvalidPrice();

    event TokenPrice(uint256 _price);
    event TokenRemoved(IERC20 indexed _token);
    event Deposit(
        address indexed depositor,
        IERC20 indexed token,
        uint256 valueOfDeposit
    );
    event DepositableToken(IERC20 indexed token, address indexed PriceFeed);

    constructor(
        address _mugen,
        address _treasury,
        address _endpoint
    ) NonblockingLzApp(_endpoint) {
        mugen = IMugen(_mugen);
        treasury = _treasury;
    }

    function deposit(IERC20Metadata _token, uint256 _amount)
        external
        nonReentrant
        depositable(_token)
    {
        if (s_totalSupply == 0) {
            s_totalSupply += 1e18;
        }
        require(_amount > 0, "Deposit must be more than 0");
        uint256 tokenPrice = usdPrice(_token);
        uint256 value = tokenPrice * _amount;
        require(value >= MIN_VALUE, "less than minimum deposit");
        uint256 calculated = _continuousMint(_amount);
        s_totalSupply += calculated;
        valueDeposited += value;
        emit Deposit(msg.sender, _token, value);
        IERC20(_token).safeTransferFrom(msg.sender, treasury, _amount);
        mugen.mint(msg.sender, calculated);
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
        emit TokenRemoved(_token);
    }

    /*************************/
    /****  View Functions ****/
    /*************************/

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

    /**************************/
    /**** Layer0 Functions ****/
    /**************************/

    /**
     * @notice Receivers value of deposits from other chains
     * updates universal token mint price and sends it back out to the chains it received it from.
     * helps keep a relatively close token mint price to one another.
     */

    function addLayerZeroMapping(address _srcTreasuryAddress, uint16 srcChain)
        external
        onlyOwner
    {
        layerZeroAddress[_srcTreasuryAddress] = srcChain;
    }

    function _nonblockingLzReceive(
        uint16,
        bytes memory _srcAddress,
        uint64, /*_nonce*/
        bytes memory _payload
    ) internal override {
        // use assembly to extract the address from the bytes memory parameter
        address sendBackToAddress;
        assembly {
            sendBackToAddress := mload(add(_srcAddress, 20))
        }
        uint16 _returnChainId = layerZeroAddress[sendBackToAddress];
        (uint256 _value, address _depositor) = abi.decode(
            _payload,
            (uint256, address)
        );
        uint256 mintAmount = _continuousMint(_value);
        s_totalSupply += mintAmount;
        bytes memory payload = abi.encode(mintAmount, _depositor);
        uint16 version = 1;
        uint256 gasForDestinationLzReceive = 350000;
        bytes memory adapterParams = abi.encodePacked(
            version,
            gasForDestinationLzReceive
        );
        _lzSend(
            _returnChainId,
            payload,
            payable(address(this)),
            address(0x0),
            adapterParams
        );
    }

    receive() external payable {}
}
