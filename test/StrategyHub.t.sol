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

contract TreasuryTest is Test {
    StrategyHub hub;
    MockERC20 mock;
    MockERC20 usdc;
    NotMockAggregator feed;
    Mugen mugen;
    LZEndpointMock Endpoint;
    Treasury treasury;
    Communicator comms;
    using stdStorage for StdStorage;
    address alice = address(0x1337);
    address jim = address(0x1234);
    address bob = address(0x5678);
    address account1 = address(0x1357);
    address account2 = address(0x2468);
    address account3 = address(0x0001);
    address account4 = address(0x0002);
    address account5 = address(0x0003);
    address account6 = address(0x0004);

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
        hub = new StrategyHub();
        mock = new MockDAI(type(uint256).max);
        usdc = new MockUSDC(type(uint256).max);
        feed = new NotMockAggregator(8, 1e8);
        Endpoint = new LZEndpointMock(1);
        mugen = new Mugen(address(Endpoint));
        comms = new Communicator(address(Endpoint), address(this));
        treasury = new Treasury(address(mugen), address(hub), address(this));
        treasury.addTokenInfo(mock, address(feed));
        treasury.addTokenInfo(usdc, address(feed));
        mock.approve(address(treasury), type(uint256).max);
        usdc.approve(address(treasury), type(uint256).max);
        mugen.setMinter(address(treasury));

        writeTokenBalance(
            address(hub),
            address(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8),
            1000000 * 1e6
        );
    }

    function testTransferStrategy() public {
        vm.expectRevert("Not Owner");
        vm.prank(alice);
        hub.addUSDCStrategies(alice, 200);
        hub.addUSDCStrategies(alice, 200);
        hub.addUSDCStrategies(jim, 200);
        hub.addUSDCStrategies(bob, 200);
        hub.addUSDCStrategies(account1, 200);
        hub.addUSDCStrategies(account2, 200);
        vm.expectRevert("Array Maxed Out");
        hub.addUSDCStrategies(alice, 200);
        hub.transferUSDCToStrategy();
        uint256 amount = (200 * 1000000 * 1e6) / 1000;
        assertEq(
            IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8).balanceOf(alice),
            amount
        );
        assertEq(
            IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8).balanceOf(bob),
            amount
        );
        assertEq(
            IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8).balanceOf(jim),
            amount
        );
        assertEq(
            IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8).balanceOf(
                address(hub)
            ),
            0
        );
        vm.expectRevert("Balance must be more than zero");
        hub.transferUSDCToStrategy();
        hub.viewUSDCStrategies();
    }
}
