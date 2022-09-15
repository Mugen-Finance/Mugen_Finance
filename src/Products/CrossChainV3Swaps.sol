//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

/**
 * TODO
 * Add other swap routes
 * Handle going from non acceptable stargate token to acceptable ones
 * Add fee (.05%);
 * Handle swap logic once on the other chain.
 */

//Current contract is not production ready and is a simply MVP

import "../interfaces/Stargate/IStargateReceiver.sol";
import "../interfaces/Stargate/IStargateRouter.sol";
import "uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "openzeppelin/contracts/token/ERC20/IERC20.sol";
import "openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISwapRouter} from "uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract CrossChainV3Swaps is IStargateReceiver {
    using SafeERC20 for IERC20;
    IStargateRouter public immutable stargateRouter;
    ISwapRouter public immutable swapRouter;

    event ReceivedOnDestination(address _token, uint256 _amountLD);
    event Swap(
        address _token,
        uint256 amountLD,
        address _swapToken,
        bool _failed
    );

    mapping(uint16 => address) destinationAddress;

    constructor(address _stargateRouter, address _swapRouter) {
        stargateRouter = IStargateRouter(_stargateRouter);
        swapRouter = ISwapRouter(_swapRouter);
    }

    struct SwapInfo {
        uint256 qty;
        address bridgeToken;
        uint16 dstChainId;
        uint16 srcPoolId;
        uint16 dstPoolId;
        address to;
        address swapToken;
        uint24 fee;
        uint256 deadline;
        address destStargateComposed;
    }

    /// @param swap Struct containing the swap data

    function crossChainSwap(SwapInfo memory swap) external payable {
        require(
            msg.value > 0,
            "stargate requires a msg.value to pay crosschain message"
        );

        require(swap.qty > 0, "error: swap() requires qty > 0");

        // encode payload data to send to destination contract, which it will handle with sgReceive()
        bytes memory data = abi.encode(swap.to, swap.swapToken, swap.fee);

        // this contract calls stargate swap()
        IERC20(swap.bridgeToken).transferFrom(
            msg.sender,
            address(this),
            swap.qty
        );
        IERC20(swap.bridgeToken).approve(address(stargateRouter), swap.qty);

        // Stargate's Router.swap() function sends the tokens to the destination chain.
        IStargateRouter(stargateRouter).swap{value: msg.value}(
            swap.dstChainId, // the destination chain id
            swap.srcPoolId, // the source Stargate poolId
            swap.dstPoolId, // the destination Stargate poolId
            payable(msg.sender), // refund adddress. if msg.sender pays too much gas, return extra eth
            swap.qty, // total tokens to send to destination chain
            0, // min amount allowed out
            IStargateRouter.lzTxObj(200000, 0, "0x"), // default lzTxObj
            abi.encodePacked(swap.destStargateComposed), // destination address, the sgReceive() implementer
            data // bytes payload
        );
    }

    /// @param _chainId The remote chainId sending the tokens
    /// @param _srcAddress The remote Bridge address
    /// @param _nonce The message ordering nonce
    /// @param _token The token contract on the local chain
    /// @param amountLD The qty of local _token contract tokens
    /// @param _payload The bytes containing the toAddress
    function sgReceive(
        uint16 _chainId,
        bytes memory _srcAddress,
        uint256 _nonce,
        address _token,
        uint256 amountLD,
        bytes memory _payload
    ) external override {
        require(
            msg.sender == address(stargateRouter),
            "only stargate router can call sgReceive!"
        );
        (address _toAddr, address _swapToken, uint24 _fee) = abi.decode(
            _payload,
            (address, address, uint24)
        );
        bool failed;
        IERC20(_token).safeIncreaseAllowance(address(swapRouter), amountLD);
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: _token,
                tokenOut: _swapToken,
                fee: _fee,
                recipient: _toAddr,
                deadline: block.timestamp,
                amountIn: amountLD,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        // The call to `exactInputSingle` executes the swap.

        try ISwapRouter(swapRouter).exactInputSingle(params) {} catch (
            bytes memory
        ) {
            IERC20(_token).transfer(_toAddr, amountLD);
            failed = true;
        }

        emit ReceivedOnDestination(_token, amountLD);
        emit Swap(_token, amountLD, _swapToken, failed);
    }

    receive() external payable {}
}
