//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import {IMyceliumStrategy} from "../../interfaces/IMyceliumStrategy.sol";
import {ERC20} from "openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "openzeppelin/contracts/access/Ownable.sol";

contract MyceliumStrategy is Ownable {
    using SafeERC20 for IERC20;

    /*///////////////////////////////////////////////////////////////
                                 Constants  
    //////////////////////////////////////////////////////////////*/

    address public constant ES_MYC = 0x7CEC785fba5ee648B48FBffc378d74C8671BB3cb;
    address public constant mycManager =
        0x2DE28AB4827112Cd3F89E5353Ca5A8D80dB7018f;

    /*///////////////////////////////////////////////////////////////
                                 Immutables 
    //////////////////////////////////////////////////////////////*/
    address public immutable weth;

    /*///////////////////////////////////////////////////////////////
                                 State Variables 
    //////////////////////////////////////////////////////////////*/

    address public administrator;
    address[] public tokens;
    address public yieldDistributor;
    address public strategyHub;
    IMyceliumStrategy public myceliumStrategy;
    uint256 public claimable;
    uint256 public compounded;
    bool public adminRemoved = false;

    /*///////////////////////////////////////////////////////////////
                                 Errors
    //////////////////////////////////////////////////////////////*/

    error NotOwner();
    error NotEnoughYield();
    error TooSoon();
    error AdminRemoved();
    error ZeroAddress();

    /*///////////////////////////////////////////////////////////////
                                 Events 
    //////////////////////////////////////////////////////////////*/

    event YieldTransfered(address indexed _caller, uint256 _amount);
    event EsMycStaked(address indexed _caller, uint256 _amount);
    event Unstaked(address indexed _caller, uint256 _amount);
    event MlpMinted(
        address indexed _caller,
        address indexed _token,
        uint256 _amount
    );
    event HubSet(address indexed _caller, address indexed _newStrategyHub);

    constructor(
        address _myceliumStrategy,
        address _weth,
        address _strategyHub
    ) {
        myceliumStrategy = IMyceliumStrategy(_myceliumStrategy);
        weth = _weth;
        strategyHub = _strategyHub;
    }

    /*///////////////////////////////////////////////////////////////
                                 User Functions  
    //////////////////////////////////////////////////////////////*/

    function stakeMycRewards() external {
        require(
            ERC20(ES_MYC).balanceOf(address(this)) > 0,
            "O balance of contract"
        );
        uint256 amount = ERC20(ES_MYC).balanceOf(address(this));
        myceliumStrategy.stakeEsMyc(amount);
        emit EsMycStaked(msg.sender, amount);
    }

    ///@notice transfers yield to the staking contract
    function transferYield() external {
        if (yieldDistributor == address(0)) revert ZeroAddress();
        uint256 amount = IERC20(weth).balanceOf(address(this));
        if (amount <= 0) {
            revert NotEnoughYield();
        }
        IERC20(weth).safeTransfer(yieldDistributor, amount);
        emit YieldTransfered(msg.sender, amount);
    }

    function mintMlp(
        address _token,
        uint256 _minUsdg,
        uint256 _minMlp
    ) external {
        require(_minUsdg > 0 && _minMlp > 0, "Inputs Must Be > 0");
        uint256 _amount = IERC20(_token).balanceOf(address(this));
        ERC20(_token).increaseAllowance(mycManager, _amount);
        IMyceliumStrategy(myceliumStrategy).mintAndStakeMlp(
            _token,
            _amount,
            _minUsdg,
            _minMlp
        );
        emit MlpMinted(msg.sender, _token, _amount);
    }

    function claimRewards() external {
        if (claimable > block.timestamp) {
            revert TooSoon();
        }
        IMyceliumStrategy(myceliumStrategy).claim();
        claimable = block.timestamp + 1 days;
    }

    function compound() external {
        if (compounded + 1 days > block.timestamp) {
            revert TooSoon();
        }
        IMyceliumStrategy(myceliumStrategy).compound();
        compounded = block.timestamp;
    }

    /*///////////////////////////////////////////////////////////////
                                 Admin Functions  
    //////////////////////////////////////////////////////////////*/

    function sellMlp(
        address _tokenOut,
        uint256 _MlpAmount,
        uint256 _minOut
    ) external onlyOwnerOrAdmin {
        IMyceliumStrategy(myceliumStrategy).unstakeAndRedeemMlp(
            _tokenOut,
            _MlpAmount,
            _minOut,
            address(this)
        );
    }

    function unstake(uint256 _amount) external onlyOwnerOrAdmin {
        IMyceliumStrategy(myceliumStrategy).unstakeEsMyc(_amount);
        emit Unstaked(msg.sender, _amount);
    }

    function removeAdmin() external onlyOwner {
        administrator = address(0);
        adminRemoved = true;
    }

    function replaceAdmin(address newAdmin) external onlyOwnerOrAdmin {
        if (adminRemoved != false) {
            revert AdminRemoved();
        }
        administrator = newAdmin;
    }

    function setYieldDistributor(address _yield) external onlyOwnerOrAdmin {
        yieldDistributor = _yield;
    }

    function setStrategyHub(address _hub) external onlyOwnerOrAdmin {
        strategyHub = _hub;
        emit HubSet(msg.sender, _hub);
    }

    function migrate() external onlyOwnerOrAdmin {
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20 token = IERC20(tokens[i]);
            address _to = strategyHub;
            uint256 assetBalance = token.balanceOf(address(this));
            if (assetBalance > 0) {
                token.transfer(_to, assetBalance);
            }
        }
    }

    function addToToken(address _token) external onlyOwnerOrAdmin {
        tokens.push(_token);
    }

    /*///////////////////////////////////////////////////////////////
                            Modifer Functions  
    //////////////////////////////////////////////////////////////*/

    modifier onlyOwnerOrAdmin() {
        if (msg.sender != administrator && msg.sender != owner()) {
            revert NotOwner();
        }
        _;
    }
}
