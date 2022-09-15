// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "../src/Strategy/StrategyHub.sol";
import "../src/Strategy/ArbitrumStrategies/GMXStrategy.sol";
import "openzeppelin/contracts/token/ERC20/IERC20.sol";

contract GMXStrategyTest is Test {
    address rewardRouter = address(0xA906F338CB21815cBc4Bc87ace9e68c87eF8d8F1);
    address glpManager = address(0x321F653eED006AD1C29D174e17d96351BDe22649);
    GMXStrategy gmxStrategy;
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
        gmxStrategy = new GMXStrategy(
            rewardRouter,
            address(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1),
            address(this)
        );
        IERC20(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1).approve(
            address(gmxStrategy),
            type(uint256).max
        );
        writeTokenBalance(
            address(gmxStrategy),
            address(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1),
            100 * 1e18
        );
    }

    function testMigration() public {
        gmxStrategy.addToToken(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);
        gmxStrategy.migrate();
        assertEq(
            IERC20(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1).balanceOf(
                address(gmxStrategy)
            ),
            0
        );
    }

    function testControlOfGMX() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        gmxStrategy.removeAdmin();
        vm.expectRevert(GMXStrategy.NotOwner.selector);
        vm.prank(alice);
        gmxStrategy.addToToken(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);
    }

    function testYield() public {
        vm.expectRevert(GMXStrategy.ZeroAddress.selector);
        gmxStrategy.transferYield();
        gmxStrategy.setYieldDistributor(alice);
        vm.expectRevert(GMXStrategy.NotEnoughYield.selector);
        gmxStrategy.transferYield();
    }

    function testMinting() public {
        vm.expectRevert("Inputs Must Be > 0");
        gmxStrategy.mintGLP(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1, 0, 0);
    }

    function testClaim() public {
        gmxStrategy.claimRewards();
        assertEq(gmxStrategy.claimable(), (block.timestamp + 1 days));
    }

    function testPush() public {
        vm.expectRevert(GMXStrategy.NotOwner.selector);
        vm.prank(alice);
        gmxStrategy.addToToken(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);
        gmxStrategy.addToToken(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);
        assertEq(
            gmxStrategy.tokens(0),
            0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1
        );
    }
}
