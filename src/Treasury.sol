//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "./NonblockingLzApp.sol";
import "openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IMugen.sol";
import "openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin/contracts/utils/math/SafeMath.sol";
import "openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/AggregatorV3Interface.sol";

contract Treasury is NonblockingLzApp, ReentrancyGuard {
    IMugen Mugen;
    address public treasury;

    mapping(IERC20 => bool) public depositableTokens;
    mapping(IERC20 => AggregatorV3Interface) public priceFeeds;
    mapping(address => uint16) public layerZeroAddress;

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

    constructor(
        address _mugen,
        address _treasury,
        address _endpoint
    ) NonblockingLzApp(_endpoint) {
        Mugen = IMugen(_mugen);
        treasury = _treasury;
    }

    function deposit(IERC20 _token, uint256 _amount)
        external
        nonReentrant
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

    /**************************/
    /****  Admin Functions ****/
    /**************************/

    function addTokenInfo(IERC20 _token, address _pricefeed)
        external
        onlyOwner
    {
        priceFeeds[_token] = AggregatorV3Interface(_pricefeed);
        depositableTokens[_token] = true;
        emit DepositableToken(_token, _pricefeed);
    }

    function removeTokenInfo(IERC20 _token) external onlyOwner {
        delete depositableTokens[_token];
        delete priceFeeds[_token];
    }

    /*************************/
    /****  View Functions ****/
    /*************************/

    function readValue() public view returns (uint256) {
        return valueDeposited;
    }

    function readPrice() external view returns (uint256) {
        return tokenMintPrice;
    }

    function getPrice(IERC20 _token) public view returns (uint256) {
        (, int256 price, , , ) = priceFeeds[_token].latestRoundData();
        return uint256(price);
    }

    function usdPrice(IERC20 _token) public view returns (uint256) {
        uint256 tokenPrice = getPrice(_token);
        uint256 tokenUsdPrice = tokenPrice.div(1e8);
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
        uint256 _value = abi.decode(_payload, (uint256));
        tokenMintPrice += _value;
        bytes memory payload = abi.encode(tokenMintPrice);
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

    function updateCrossChainPrice(uint16 _dstChainId) external {
        bytes memory payload = abi.encode(tokenMintPrice);
        uint16 version = 1;
        uint256 gasForDestinationLzReceive = 350000;
        bytes memory adapterParams = abi.encodePacked(
            version,
            gasForDestinationLzReceive
        );
        _lzSend(
            _dstChainId,
            payload,
            payable(address(this)),
            address(0x0),
            adapterParams
        );
    }

    receive() external payable {}
}
