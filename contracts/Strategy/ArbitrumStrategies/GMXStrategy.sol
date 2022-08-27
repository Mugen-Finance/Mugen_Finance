//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import {IRewardRouterV2} from "../../interfaces/IRewardRouterV2.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract GMXStrategy is Ownable {
    IRewardRouterV2 rewardRouterV2;

    using SafeERC20 for IERC20;

    address public administrator;
    address public yieldDistributor;
    address public constant ES_GMX = 0xf42Ae1D54fd613C9bb14810b0588FaAa09a426cA;
    address public constant glpManager =
        0x321F653eED006AD1C29D174e17d96351BDe22649;
    address public immutable weth;
    uint256 public claimable;
    uint256 public compounded;
    bool public adminRemoved = false;

    error NotOwner();
    error NotEnoughYield();
    error TooSoon();
    error AdminRemoved();

    event YieldTransfered(address indexed _caller, uint256 _amount);
    event EsGMXStaked(address indexed _caller, uint256 _amount);
    event Unstaked(address indexed _caller, uint256 _amount);
    event GlpMinted(
        address indexed _caller,
        address indexed _token,
        uint256 _amount,
        uint256 _glpAmount
    );

    constructor(address _rewardRouterV2, address _weth) {
        rewardRouterV2 = IRewardRouterV2(_rewardRouterV2);
        administrator = msg.sender;
        weth = _weth;
    }

    function stakeGMXRewards() external {
        require(
            ERC20(ES_GMX).balanceOf(address(this)) > 0,
            "O balance of contract"
        );
        uint256 amount = ERC20(ES_GMX).balanceOf(address(this));
        rewardRouterV2.stakeEsGmx(amount);
        emit EsGMXStaked(msg.sender, amount);
    }

    function mintGLP(
        address _token,
        uint256 _minUsdg,
        uint256 _minGlp
    ) external returns (uint256) {
        uint256 _amount = IERC20(_token).balanceOf(address(this));
        ERC20(_token).increaseAllowance(glpManager, _amount);
        uint256 glpAmount = rewardRouterV2.mintAndStakeGlp(
            _token,
            _amount,
            _minUsdg,
            _minGlp
        );
        emit GlpMinted(msg.sender, _token, _amount, glpAmount);
        return glpAmount;
    }

    //280466801.751895406181584300

    function sellGlp(
        address _tokenOut,
        uint256 _glpAmount,
        uint256 _minOut
    ) external onlyOwners {
        rewardRouterV2.unstakeAndRedeemGlp(
            _tokenOut,
            _glpAmount,
            _minOut,
            address(this)
        );
    }

    function unstake(uint256 _amount) external onlyOwners {
        rewardRouterV2.unstakeEsGmx(_amount);
        emit Unstaked(msg.sender, _amount);
    }

    function claimRewards() external {
        if (claimable > block.timestamp) {
            revert TooSoon();
        }
        rewardRouterV2.claim();
        claimable = block.timestamp + 1 days;
    }

    function removeAdmin() external onlyOwner {
        administrator = address(0);
    }

    function replaceAdmin(address newAdmin) external onlyOwners {
        if (adminRemoved != false) {
            revert AdminRemoved();
        }
        administrator = newAdmin;
    }

    function compound() external {
        if (compounded > block.timestamp) {
            revert TooSoon();
        }
        rewardRouterV2.compound();
        compounded = block.timestamp + 1 days;
    }

    function setYieldDistributor(address _yield) external onlyOwners {
        yieldDistributor = _yield;
    }

    function transferYield() external {
        if (IERC20(weth).balanceOf(address(this)) <= 0) {
            revert NotEnoughYield();
        }
        uint256 amount = IERC20(weth).balanceOf(address(this));
        IERC20(weth).safeTransfer(yieldDistributor, amount);
        emit YieldTransfered(msg.sender, amount);
    }

    modifier onlyOwners() {
        if (msg.sender != administrator || msg.sender != owner()) {
            revert NotOwner();
        }
        _;
    }
}