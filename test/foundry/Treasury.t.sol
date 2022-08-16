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
    NotMockAggregator feed;
    Mugen mugen;
    LZEndpointMock Endpoint;
    Treasury treasury;
    Communicator comms;
    address alice = address(0x1337);

    function setUp() public {
        mock = new MockUSDC(type(uint256).max);
        feed = new NotMockAggregator(8, 100000000);
        Endpoint = new LZEndpointMock(1);
        mugen = new Mugen(address(Endpoint));
        comms = new Communicator(address(Endpoint));
        treasury = new Treasury(address(mugen), alice, address(Endpoint));
        treasury.addTokenInfo(mock, address(feed));
        mock.approve(address(treasury), type(uint256).max);
        mugen.transferOwnership(address(treasury));
    }

    function testSetUp() public {
        assertEq(treasury.readSupply(), 1e18);
        assertEq(treasury.owner(), address(this));
        assertEq(treasury.treasury(), alice);
        assertEq(mugen.owner(), address(treasury));
    }

    function testDeposits() public {
        vm.expectRevert("Deposit must be more than 0");
        treasury.deposit(mock, 0);
        vm.expectRevert("less than min deposit");
        treasury.deposit(mock, 90 * 1e18);
        uint256 expected = treasury.calculateContinuousMintReturn(23523 * 1e18);
        treasury.deposit(mock, 23523 * 1e18);
        assertEq(expected, mugen.totalSupply());
        assertEq(expected, mugen.balanceOf(address(this)));
        assertEq(treasury.readSupply(), expected + 1e18);
        vm.expectRevert(Treasury.NotOwner.selector);
        vm.prank(alice);
        treasury.removeTokenInfo(mock);
        vm.expectRevert(Treasury.NotOwner.selector);
        vm.prank(alice);
        treasury.setCommunicator(alice);
    }
}
