//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMugen} from "../interfaces/IMugen.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {AggregatorPriceFeeds} from "../interfaces/AggregatorPriceFeeds.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {BancorFormula} from "../Bancor/BancorFormula.sol";
import {ITreasury} from "../interfaces/ITreasury.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title Mugen Treasury
 * @author Mugen Dev
 * @notice Minimal implementation of Bancors Power.sol
 * to allow users to deposit and exchange whitelisted ERC20 at usd value for
 * Mugen ERC20 tokens.
 */

contract Treasury is BancorFormula, ITreasury, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*///////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant SCALE = 10**18;
    uint256 internal constant VALID_PERIOD = 1 days;
    uint256 internal constant MIN_VALUE = 50 * 10**18;
    uint256 public constant RESERVE_RATIO = 800000;

    /*///////////////////////////////////////////////////////////////
                                IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    address public immutable treasury;
    IMugen public immutable mugen;

    /*///////////////////////////////////////////////////////////////
                                 State Variables
    //////////////////////////////////////////////////////////////*/

    uint256 public reserveBalance = 10 * SCALE;
    uint256 public valueDeposited;
    uint256 public s_totalSupply;
    uint256 public depositCap;
    address public administrator;
    address public Communicator;
    bool public adminRemoved = false;

    /*///////////////////////////////////////////////////////////////
                                 Mappings
    //////////////////////////////////////////////////////////////*/

    ///@notice listed of whitelisted ERC20s that can be deposited
    mapping(IERC20 => bool) public depositableTokens;

    ///@notice token address point to their associated price feeds.
    mapping(IERC20 => AggregatorPriceFeeds) public priceFeeds;

    /*///////////////////////////////////////////////////////////////
                                 Custom Errors
    //////////////////////////////////////////////////////////////*/

    error NotDepositable();
    error NotUpdated();
    error InvalidPrice();
    error NotOwner();
    error NotCommunicator();
    error UnderMinDeposit();
    error CapReached();
    error AdminRemoved();

    /**
     * @param _mugen Mugen ERC20 address
     * @param _treasury The treasury address that controls deposited funds
     * @param _administrator address with high level access controls
     * @notice administrator is kept initially for efficency in the early stages
     * but can be removed through governance at anytime.
     */
    constructor(
        address _mugen,
        address _treasury,
        address _administrator
    ) {
        mugen = IMugen(_mugen);
        treasury = _treasury;
        s_totalSupply += 1e18;
        administrator = _administrator;
    }

    /*///////////////////////////////////////////////////////////////
                                 User Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev allows for users to deposit whitelisted assets and calculates their USD value for the bonding curve
     * given that the cap is not reached yet.
     * @param _token the token which is to be deposited
     * @param _amount the amount for this particular deposit
     * @notice uses s_totalSupply rather than totalsupply() in order to prevent
     * accounting issues once launched on multiple chains. As the treasury will serve as
     * the global truth for pricing in the mint function.
     */

    function deposit(IERC20Metadata _token, uint256 _amount)
        external
        nonReentrant
        depositable(_token)
        Capped
    {
        uint256 amount = _amount;
        if (IERC20Metadata(_token).decimals() != 18) {
            amount = (amount * 1e18) / 10**(IERC20Metadata(_token).decimals());
        }
        require(amount > 0, "Deposit must be more than 0");
        uint256 tokenPrice = getPrice(_token);
        uint256 value = (tokenPrice * amount) /
            10**(priceFeeds[_token].decimals());
        require(value >= MIN_VALUE, "less than min deposit");
        uint256 calculated = _continuousMint(value);
        s_totalSupply += calculated;
        valueDeposited += value;
        emit Deposit(msg.sender, _token, value);
        IERC20(_token).safeTransferFrom(msg.sender, treasury, _amount);
        mugen.mint(msg.sender, calculated);
    }

    /*///////////////////////////////////////////////////////////////
                            Cross Chain Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice receives information from the Communicator and
     * relays it back to be sent to other chains.
     * @param _amount value of the deposit on the specific chain
     */

    function receiveMessage(uint256 _amount)
        external
        override
        returns (uint256)
    {
        if (msg.sender != Communicator) {
            revert NotCommunicator();
        }
        uint256 test = _continuousMint(_amount);
        s_totalSupply += test;
        return test;
    }

    /*///////////////////////////////////////////////////////////////
                                 Admin Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice adds token to whitelisted assets with its associated oracle
     * @param _token address of the token
     * @param _pricefeed address for the pricefeed
     */

    function addTokenInfo(IERC20 _token, address _pricefeed) external {
        if (msg.sender != owner() || msg.sender != administrator) {
            revert NotOwner();
        }
        priceFeeds[_token] = AggregatorPriceFeeds(_pricefeed);
        depositableTokens[_token] = true;
        emit DepositableToken(_token, _pricefeed);
    }

    /**
     * @notice Removes the token from the list of
     * whitelisted assets and its associated oracle
     * @param _token address of the token
     */
    function removeTokenInfo(IERC20 _token) external {
        if (msg.sender != owner() || msg.sender != administrator) {
            revert NotOwner();
        }
        delete depositableTokens[_token];
        delete priceFeeds[_token];
        emit TokenRemoved(_token);
    }

    ///@param _comms address of the communicator contract
    function setCommunicator(address _comms) external {
        if (msg.sender != owner() || msg.sender != administrator) {
            revert NotOwner();
        }
        Communicator = _comms;
    }

    /**
     * @notice setting the cap for inital deposits while code is fresh
     * @param _amount what the Capp is set to
     * @dev the cap will be evaluated in USD from the valueDeposited variable
     * so 100 * 1e18 will set the cap to 100 USD
     */
    function setCap(uint256 _amount) external {
        if (msg.sender != owner() || msg.sender != administrator) {
            revert NotOwner();
        }
        depositCap = _amount;
    }

    /**
     * @notice removes the admin and set it to the zero address
     * @dev once removed a new admin cannot be set
     * @param newAdmin the address of the new Administrator
     */
    function setAdministrator(address newAdmin) external {
        if (adminRemoved != false) {
            revert AdminRemoved();
        }
        require(
            msg.sender == owner() || msg.sender == administrator,
            "not the owner"
        );
        administrator = newAdmin;
    }

    ///@notice permenantly removes the administrator from being able
    /// to preform functions and have access control
    function removeAdmin() external onlyOwner {
        administrator = address(0);
        adminRemoved = true;
    }

    /*///////////////////////////////////////////////////////////////
                            View Functions
    //////////////////////////////////////////////////////////////*/

    function getPrice(IERC20 _token) internal view returns (uint256) {
        (, int256 price, , uint256 updatedAt, ) = priceFeeds[_token]
            .latestRoundData();
        if (block.timestamp - updatedAt > VALID_PERIOD) {
            revert NotUpdated();
        }
        if (price <= 0) {
            revert InvalidPrice();
        }
        return uint256(price);
    }

    function readSupply() external view returns (uint256) {
        return s_totalSupply;
    }

    function checkDepositable(IERC20 _token) external view returns (bool) {
        return depositableTokens[_token];
    }

    ///@notice returns the current USD price to mint 1 Mugen Token
    function pricePerToken() external view returns (uint256) {
        uint256 _price = (100 * 1e18) / calculateContinuousMintReturn(1e18);
        return _price;
    }

    /*///////////////////////////////////////////////////////////////
                        Modifier Functions 
    //////////////////////////////////////////////////////////////*/

    modifier depositable(IERC20 _token) {
        if (depositableTokens[_token] != true) {
            revert NotDepositable();
        }
        _;
    }

    modifier Capped() {
        if (depositCap < valueDeposited) {
            revert CapReached();
        }
        _;
    }

    /*///////////////////////////////////////////////////////////////
                        Bonding Curve Logic
    //////////////////////////////////////////////////////////////*/

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
