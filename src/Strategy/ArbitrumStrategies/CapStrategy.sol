//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

/**
 * TODO
 * Swap Logic
 * Test
 */

import "../../interfaces/ICapUSDCReward.sol";
import "openzeppelin/contracts/access/Ownable.sol";
import "openzeppelin/contracts/token/ERC20/IERC20.sol";
import "openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import {ISwapRouter} from "uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract CapStrategy is Ownable {
    using SafeERC20 for IERC20;

    ICapStrategy public cap;
    ICapUSDCReward public usdcReward;
    ISwapRouter public immutable swapRouter;
    address public yieldDistributor;

    address public constant USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address public constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    uint256 public claimed;

    event Migrated(
        address indexed _caller,
        address indexed _recipient,
        uint256 _amount
    );

    constructor(
        address _cap,
        address _usdcReward,
        address _swapRouter,
        address _yieldDistributor
    ) {
        cap = ICapStrategy(_cap);
        usdcReward = ICapUSDCReward(_usdcReward);
        swapRouter = ISwapRouter(_swapRouter);
        yieldDistributor = _yieldDistributor;
    }

    function depositUSDC() external {
        uint256 amount = IERC20(USDC).balanceOf(address(this));
        cap.deposit(amount);
    }

    function withdrawUSDC(uint256 _amount) external onlyOwner {
        cap.withdraw(_amount);
    }

    function claimUSDCRewards() external {
        claimed = checkReward();
        usdcReward.collectReward();
    }

    function checkReward() internal view returns (uint256) {
        uint256 amount = usdcReward.getClaimableReward();
        return amount;
    }

    function swap() external {
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: USDC,
                tokenOut: WETH,
                fee: 500,
                recipient: yieldDistributor,
                deadline: block.timestamp,
                amountIn: claimed,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        uint256 amountOut = ISwapRouter(swapRouter).exactInputSingle(params);
        IERC20(WETH).safeTransfer(yieldDistributor, amountOut);
    }

    function migrate(address _to) external onlyOwner {
        uint256 amount = IERC20(USDC).balanceOf(address(this));
        IERC20(USDC).safeTransfer(_to, amount);
        emit Migrated(msg.sender, _to, amount);
    }
}
