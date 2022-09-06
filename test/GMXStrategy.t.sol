// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "../src/Mugen/Communicator.sol";
import "../src/Mugen/Treasury.sol";
import "../src/mocks/LZEndpointMock.sol";
import "../src/Mugen/Mugen.sol";
import "../src/mocks/MockERC20.sol";
import "../src/mocks/NotMockAggregator.sol";
import "../src/Strategy/StrategyHub.sol";
import "../src/Strategy/ArbitrumStrategies/GMXStrategy.sol";
import "openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/mocks/MockERC20.sol";

contract GMXStrategyTest is Test {
    address rewardRouter = address(0xA906F338CB21815cBc4Bc87ace9e68c87eF8d8F1);
    address glpManager = address(0x321F653eED006AD1C29D174e17d96351BDe22649);
    GMXStrategy gmxStrategy;
    MockERC20 weth;
    using stdStorage for StdStorage;
    address alice = address(0x1337);
    address fsGlp = address(0x1aDDD80E6039594eE970E5872D247bf0414C8903);

    function writeTokenBalance(
        address who,
        address token,
        uint256 amt
    ) internal {
        stdstore
            .target(token)
            .sig(IERC20(token).balanceOf.selector)
            .with_key(who)
            .checked_write(amt);
    }

    function setUp() public {
        weth = new MockERC20("weth", "weth", 18, type(uint256).max);
        gmxStrategy = new GMXStrategy(
            rewardRouter,
            address(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1)
        );
        weth.approve(address(gmxStrategy), type(uint256).max);
        gmxStrategy.setYieldDistributor(alice);

        writeTokenBalance(
            address(gmxStrategy),
            address(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1),
            1000 * 1e18
        );
    }

    function testMinting() public {
        uint256 amount = gmxStrategy.mintGLP(
            address(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1),
            100 * 1e18,
            100 * 1e18
        );
        assertEq(amount, IERC20(fsGlp).balanceOf(address(gmxStrategy)));
        vm.warp(1 days);
        gmxStrategy.claimRewards();
    }
}
