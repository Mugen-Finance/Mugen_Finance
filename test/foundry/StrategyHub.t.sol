// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "../../contracts/Mugen/Communicator.sol";
import "../../contracts/Mugen/Treasury.sol";
import "../../contracts/mocks/LZEndpointMock.sol";
import "../../contracts/Mugen/Mugen.sol";
import "../../contracts/mocks/MockERC20.sol";
import "../../contracts/mocks/NotMockAggregator.sol";
import "../../contracts/Strategy/StrategyHub.sol";

contract TreasuryTest is Test {
    StrategyHub hub;
    MockERC20 mock;
    MockERC20 usdc;
    NotMockAggregator feed;
    Mugen mugen;
    LZEndpointMock Endpoint;
    Treasury treasury;
    Communicator comms;
    address alice = address(0x1337);

    function setUp() public {
        hub = new StrategyHub();
        mock = new MockDAI(type(uint256).max);
        usdc = new MockUSDC(type(uint256).max);
        feed = new NotMockAggregator(8, 1e8);
        Endpoint = new LZEndpointMock(1);
        mugen = new Mugen(address(Endpoint));
        comms = new Communicator(address(Endpoint));
        treasury = new Treasury(address(mugen), address(hub), address(this));
        treasury.addTokenInfo(mock, address(feed));
        treasury.addTokenInfo(usdc, address(feed));
        mock.approve(address(treasury), type(uint256).max);
        usdc.approve(address(treasury), type(uint256).max);
        mugen.setMinter(address(treasury));
    }

    function testTransferStrategy() public {
        assertEq(hub.administrator(), address(this));
        treasury.deposit(mock, 1000 * 1e18);
        assertEq(mock.balanceOf(address(hub)), 1000 * 1e18);
        vm.expectRevert(StrategyHub.NotAStrategy.selector);
        hub.transferToStrategy(mock, alice);
        hub.addStrategies(alice);
        vm.expectRevert(StrategyHub.NotAStrategy.selector); //Fix customer error
        hub.transferToStrategy(mock, alice);
        hub.addTransferableTokens(alice, mock);
        vm.expectRevert(StrategyHub.NotOwner.selector);
        vm.prank(alice);
        hub.updatePercentage(1000, alice);
        hub.updatePercentage(500, alice);
        vm.expectRevert("Invalid Percentages");
        hub.updatePercentage(1500, alice);
        vm.expectRevert("Invalid Percentages");
        hub.updatePercentage(0, alice);
        hub.transferToStrategy(mock, alice);
        assertEq(mock.balanceOf(alice), 500 * 1e18);
        vm.expectRevert(StrategyHub.StrategyCooldown.selector);
        hub.transferToStrategy(mock, alice);
        uint256 cooldownTime = hub.checkCooldown(alice);
        uint256 day = 2 days;
        assertEq(cooldownTime, block.timestamp + day);
    }

    function testLocks() public {}
}
