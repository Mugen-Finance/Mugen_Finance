// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;
pragma abicoder v2;

//Add liquidity lock
//When withdrawing will need to call collect all fees to get from the contract.
//Dealing with the owner being the only one that can add liquidity.
//Sending the withdrawn funds to the strategy hub in need be.
//Accounting for sells. Weth balance snap shot, modifier function

import "openzeppelin/contracts/token/ERC20/IERC20.sol";
import "openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "openzeppelin/contracts/access/Ownable.sol";
import "openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

contract LiquidityStrategy is Ownable, IERC721Receiver {
    using SafeERC20 for IERC20;

    address public constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public constant MGN = 0xFc77b86F3ADe71793E1EEc1E7944DB074922856e;

    uint24 public constant poolFee = 3000;

    uint256 public unlockTime;
    uint256 public wethForSale;

    address public yieldDepositor;

    INonfungiblePositionManager public constant nonfungiblePositionManager =
        INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    event locked(
        address indexed _caller,
        uint256 _lockTime,
        uint256 _unlockTime
    );

    event CollectedRewards(uint256 _mugenRewards, uint256 _wethRewards);

    /// notice Represents the deposit of an NFT
    struct Deposit {
        address owner;
        uint128 liquidity;
        address token0;
        address token1;
    }

    /// dev deposits[tokenId] => Deposit
    mapping(uint256 => Deposit) public deposits;

    constructor() {}

    // Implementing `onERC721Received` so this contract can receive custody of erc721 tokens
    function onERC721Received(
        address operator,
        address,
        uint256 tokenId,
        bytes calldata
    ) external returns (bytes4) {
        // get position information

        _createDeposit(operator, tokenId);

        return this.onERC721Received.selector;
    }

    function _createDeposit(address owner, uint256 tokenId) internal {
        (
            ,
            ,
            address token0,
            address token1,
            ,
            ,
            ,
            uint128 liquidity,
            ,
            ,
            ,

        ) = nonfungiblePositionManager.positions(tokenId);

        // set the owner and data for position
        // operator is msg.sender
        deposits[tokenId] = Deposit({
            owner: owner,
            liquidity: liquidity,
            token0: token0,
            token1: token1
        });
    }

    /// notice Calls the mint function defined in periphery, mints the same amount of each token.
    /// For this example we are providing 1000 WETH and 1000 MGN in liquidity
    /// return tokenId The id of the newly minted ERC721
    /// return liquidity The amount of liquidity for the position
    /// return amount0 The amount of token0
    /// return amount1 The amount of token1

    /// notice Collects the fees associated with provided liquidity
    /// dev The contract must hold the erc721 token before it can collect fees
    /// param tokenId The id of the erc721 token
    /// return amount0 The amount of fees collected in token0
    /// return amount1 The amount of fees collected in token1
    function collectAllFees(uint256 tokenId)
        internal
        returns (uint256 amount0, uint256 amount1)
    {
        // Caller must own the ERC721 position, meaning it must be a deposit

        // set amount0Max and amount1Max to uint256.max to collect all fees
        // alternatively can set recipient to msg.sender and avoid another transaction in `sendToOwner`
        INonfungiblePositionManager.CollectParams
            memory params = INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });

        (amount0, amount1) = nonfungiblePositionManager.collect(params);
    }

    /// notice A function that decreases the current liquidity by half. An example to show how to call the `decreaseLiquidity` function defined in periphery.
    /// param tokenId The id of the erc721 token
    /// return amount0 The amount received back in token0
    /// return amount1 The amount returned back in token1
    function decreaseLiquidityInHalf(uint256 tokenId)
        external
        ifUnlocked
        returns (uint256 amount0, uint256 amount1)
    {
        // caller must be the owner of the NFT
        require(msg.sender == deposits[tokenId].owner, "Not the owner");
        // get liquidity data for tokenId
        uint128 liquidity = deposits[tokenId].liquidity;
        uint128 halfLiquidity = liquidity / 2;

        // amount0Min and amount1Min are price slippage checks
        // if the amount received after burning is not greater than these minimums, transaction will fail
        INonfungiblePositionManager.DecreaseLiquidityParams
            memory params = INonfungiblePositionManager
                .DecreaseLiquidityParams({
                    tokenId: tokenId,
                    liquidity: halfLiquidity,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                });

        (amount0, amount1) = nonfungiblePositionManager.decreaseLiquidity(
            params
        );
    }

    /// notice Increases liquidity in the current range
    /// dev Pool must be initialized already to add liquidity
    /// param tokenId The id of the erc721 token
    /// param amount0 The amount to add of token0
    /// param amount1 The amount to add of token1
    function increaseLiquidityCurrentRange(
        uint256 tokenId,
        uint256 amountAdd0,
        uint256 amountAdd1
    )
        external
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        TransferHelper.safeTransferFrom(
            deposits[tokenId].token0,
            msg.sender,
            address(this),
            amountAdd0
        );
        TransferHelper.safeTransferFrom(
            deposits[tokenId].token1,
            msg.sender,
            address(this),
            amountAdd1
        );

        TransferHelper.safeApprove(
            deposits[tokenId].token0,
            address(nonfungiblePositionManager),
            amountAdd0
        );
        TransferHelper.safeApprove(
            deposits[tokenId].token1,
            address(nonfungiblePositionManager),
            amountAdd1
        );

        INonfungiblePositionManager.IncreaseLiquidityParams
            memory params = INonfungiblePositionManager
                .IncreaseLiquidityParams({
                    tokenId: tokenId,
                    amount0Desired: amountAdd0,
                    amount1Desired: amountAdd1,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                });

        (liquidity, amount0, amount1) = nonfungiblePositionManager
            .increaseLiquidity(params);
    }

    /// notice Transfers funds to owner of NFT
    /// param tokenId The id of the erc721
    /// param amount0 The amount of token0
    /// param amount1 The amount of token1
    function _sendToOwner(
        uint256 tokenId,
        uint256 amount0,
        uint256 amount1
    ) internal {
        // get owner of contract
        address owner = deposits[tokenId].owner;

        address token0 = deposits[tokenId].token0;
        address token1 = deposits[tokenId].token1;
        // send collected fees to owner
        TransferHelper.safeTransfer(token0, owner, amount0);
        TransferHelper.safeTransfer(token1, owner, amount1);
    }

    /// notice Transfers the NFT to the owner
    /// param tokenId The id of the erc721
    function retrieveNFT(uint256 tokenId) external ifUnlocked {
        // must be the owner of the NFT
        require(msg.sender == deposits[tokenId].owner, "Not the owner");
        // transfer ownership to original owner
        nonfungiblePositionManager.safeTransferFrom(
            address(this),
            msg.sender,
            tokenId
        );
        //remove information related to tokenId
        delete deposits[tokenId];
    }

    function burnMGN(uint256 _tokenId) external {
        require(yieldDepositor != address(0), "Yield Depositor Not Set");
        (uint256 wethRewards, uint256 mugenRewards) = collectAllFees(_tokenId);
        IERC20(MGN).safeTransfer(address(0), mugenRewards);
        IERC20(WETH).safeTransfer(yieldDepositor, wethRewards);
        emit CollectedRewards(mugenRewards, wethRewards);
    }

    function lock() external onlyOwner {
        unlockTime = block.timestamp + 365 days;
        emit locked(msg.sender, block.timestamp, unlockTime);
    }

    modifier ifUnlocked() {
        require(block.timestamp >= unlockTime, "Liquidity Locked");
        _;
    }
    modifier buyBack() {
        _;
        require(wethForSale >= 0, "Sale Completed");
    }
}
