// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "../src/mocks/MockERC20.sol";
import "../src/Mugen/YieldDistributor.sol";
import "../src/Mugen/xMugen.sol";
import "../src/Mugen/Mugen.sol";
import "../src/Mugen/Treasury.sol";
import "../src/mocks/NotMockAggregator.sol";

contract TestYieldDistributor is Test {
    NotMockAggregator mockFeed;
    Treasury treasury;
    Mugen mugen;
    xMugen xMGN;
    YieldDistributor yield;
    MockERC20 mock;
    address rewardsContract = address(0x1337);
    address teamFund = address(0x1234);
    address alice = address(0x1111);

    function setUp() public {
        mugen = new Mugen(alice);
        mock = new MockDAI(10000 * 1e18);
        xMGN = new xMugen(address(mugen), address(mock));
        yield = new YieldDistributor(teamFund, address(mock));
        treasury = new Treasury(address(mugen), address(yield), address(this));
        mock.approve(address(treasury), 10000 * 1e18);
        mock.approve(address(yield), 1e40);

        mugen.setMinter(address(treasury));
        mockFeed = new NotMockAggregator(8, 1e8);
        treasury.addTokenInfo(mock, address(mockFeed));
        mugen.approve(address(xMGN), 1e25);
        xMGN.setYield(address(yield));
        yield.setStaking(address(xMGN));
    }

    function testTransferRewards() public {
        treasury.deposit(mock, 4533 * 1e18);
        xMGN.deposit(30 * 1e18, address(this));
        vm.warp(100);
        address(xMGN);
        yield.transferRewards();
        uint256 team = (4533 * 1e18 * 100) / 1000;
        uint256 rewards = (4533 * 1e18 * 900) / 1000;
        assertEq(mock.balanceOf(address(xMGN)), rewards);
        assertEq(mock.balanceOf(teamFund), team);
        assertEq(mock.balanceOf(address(yield)), 0);
    }

    function testConstraints() public {
        treasury.deposit(mock, 1000 * 1e18);
        xMGN.deposit(30 * 1e18, address(this));
        mock.transfer(address(yield), 1000 * 1e18);
        vm.expectRevert("not the owner");
        vm.prank(alice);
        yield.setStaking(address(xMGN));
        yield.transferRewards();
        vm.expectRevert(YieldDistributor.RewardsToLow.selector);
        yield.transferRewards();
        vm.expectRevert("not the owner");
        vm.prank(alice);
        yield.setAdministrator(alice);
        yield.removeAdmin();
        vm.expectRevert(YieldDistributor.AdminRemoved.selector);
        yield.setAdministrator(alice);
    }
}
