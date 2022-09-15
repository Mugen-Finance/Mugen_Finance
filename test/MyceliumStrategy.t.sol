// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "../src/Strategy/ArbitrumStrategies/MyceliumStrategy.sol";
import "openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MyceliumStrategyTest is Test {
    using stdStorage for StdStorage;
    address myceliumRouter =
        address(0xd98d8e458F7aD22DD3C1d7A8B35C74005eb52b0b);
    address mlpManger = address(0x2DE28AB4827112Cd3F89E5353Ca5A8D80dB7018f);
    MyceliumStrategy myceliumStrategy;
    address alice = address(0x1337);
    address fsMLP = address(0xF7Bd2ed13BEf9C27a2188f541Dc5ED85C5325306);

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
        myceliumStrategy = new MyceliumStrategy(
            myceliumRouter,
            address(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8),
            address(this)
        );
        IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8).approve(
            address(myceliumStrategy),
            type(uint256).max
        );
        writeTokenBalance(
            address(myceliumStrategy),
            address(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8),
            1000 * 1e6
        );
    }

    function testMintingMlp() public {
        myceliumStrategy.mintMlp(
            0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8,
            1,
            1
        );
        assertEq(
            IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8).balanceOf(
                address(myceliumStrategy)
            ),
            0
        );
        assertGt(
            IERC20(0xF7Bd2ed13BEf9C27a2188f541Dc5ED85C5325306).balanceOf(
                address(myceliumStrategy)
            ),
            850 * 1e18
        );
    }

    function testSellingMlp() public {
        testMintingMlp();
        vm.warp(1 days);
        myceliumStrategy.sellMlp(
            0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8,
            850 * 1e18,
            100 * 1e18
        );
    }
}
