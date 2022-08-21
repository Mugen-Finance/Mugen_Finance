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

contract TreasuryTest is Test {
    MockERC20 mock;
    MockERC20 usdc;
    NotMockAggregator feed;
    Mugen mugen;
    LZEndpointMock Endpoint;
    Treasury treasury;
    Communicator comms;
    address alice = address(0x1337);

    function setUp() public {
        mock = new MockDAI(type(uint256).max);
        usdc = new MockUSDC(type(uint256).max);
        feed = new NotMockAggregator(8, 1e8);
        Endpoint = new LZEndpointMock(1);
        mugen = new Mugen(address(Endpoint));
        comms = new Communicator(address(Endpoint));
        treasury = new Treasury(address(mugen), alice);
        treasury.addTokenInfo(mock, address(feed));
        treasury.addTokenInfo(usdc, address(feed));
        mock.approve(address(treasury), type(uint256).max);
        usdc.approve(address(treasury), type(uint256).max);
        mugen.transferOwnership(address(treasury));
    }

    function testSetUp() public {
        assertEq(treasury.readSupply(), 1e18);
        assertEq(treasury.owner(), address(this));
        assertEq(treasury.treasury(), alice);
        assertEq(mugen.owner(), address(treasury));
    }

    function testDeposit() public {
        vm.expectRevert("Deposit must be more than 0");
        treasury.deposit(mock, 0);
        vm.expectRevert("less than min deposit");
        treasury.deposit(mock, 99 * 1e18);
        uint256 expected = treasury.calculateContinuousMintReturn(1000 * 1e18);
        treasury.deposit(mock, 1000 * 1e18);
        assertEq(mugen.totalSupply(), expected);
        assertEq(treasury.readSupply(), expected + 1e18);
        assertEq(mugen.balanceOf(address(this)), expected);
        assertEq(mock.balanceOf(alice), 1000 * 1e18);
    }

    function testDecimals() public {
        uint256 expected = treasury.calculateContinuousMintReturn(1000 * 1e18);
        treasury.deposit(usdc, 1000 * 1e6);
        assertEq(mugen.totalSupply(), expected);
        assertEq(treasury.readSupply(), expected + 1e18);
        assertEq(mugen.balanceOf(address(this)), expected);
        assertEq(usdc.balanceOf(alice), 1000 * 1e6);
        assertEq(treasury.valueDeposited(), 1000 * 1e18);
    }

    function testAdmin() public {
        vm.expectRevert(Treasury.NotOwner.selector);
        vm.prank(alice);
        treasury.addTokenInfo(mock, address(feed));
        vm.expectRevert(Treasury.NotOwner.selector);
        vm.prank(alice);
        treasury.removeTokenInfo(mock);
        vm.expectRevert(Treasury.NotOwner.selector);
        vm.prank(alice);
        treasury.setCommunicator(address(comms));
        //
        assertEq(treasury.depositableTokens(mock), true);
        assertEq(treasury.depositableTokens(usdc), true);
        treasury.removeTokenInfo(mock);
        treasury.removeTokenInfo(usdc);
        assertEq(treasury.depositableTokens(mock), false);
        assertEq(treasury.depositableTokens(usdc), false);
        //
        treasury.setCommunicator(address(comms));
        assertEq(treasury.Communicator(), address(comms));
        vm.expectRevert(Treasury.NotCommunicator.selector);
        treasury.receiveMessage(100 * 1e18);
    }
}
