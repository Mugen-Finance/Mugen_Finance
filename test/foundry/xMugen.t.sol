// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "../../contracts/Mugen/xMugen.sol";
import "../../contracts/Mugen/Mugen.sol";
import "../../contracts/mocks/MockERC20.sol";
import "../../contracts/mocks/LZEndpointMock.sol";

contract xMugenTest is Test {
    LZEndpointMock EndPoint;
    MockERC20 mock;
    Mugen mugen;
    xMugen xMGN;
    address alice = address(0x1337);
    address bob = address(0x4321);

    function setUp() public {
        mock = new MockDAI(type(uint256).max);
        EndPoint = new LZEndpointMock(1);
        mugen = new Mugen(address(EndPoint));
        mugen.mint(address(this), type(uint104).max);
        mugen.transfer(alice, 1000 * 1e18);
        xMGN = new xMugen(address(mugen), address(mock));
        mock.approve(address(xMGN), type(uint256).max);
        mugen.approve(address(xMGN), type(uint256).max);
        vm.prank(alice);
        mugen.approve(address(xMGN), type(uint256).max);
        xMGN.setYield(address(this));
    }

    function testIssuance(uint192 amount) public {
        vm.assume(amount > 0);
        vm.expectRevert(xMugen.NotYield.selector);
        vm.prank(alice);
        xMGN.issuanceRate(100 * 1e18);
        vm.expectRevert("xMGN:UVS:ZERO_SUPPLY");
        xMGN.issuanceRate(100 * 1e18);
        xMGN.deposit(1e18, address(this));
        xMGN.issuanceRate(amount);
        uint256 time = 30 days;
        assertEq(xMGN.rewardRate(), amount / time);
        assertEq(mock.balanceOf(address(xMGN)), amount);
        assertEq(xMGN.lastUpdateTime(), block.timestamp);
        assertEq(xMGN.periodFinish(), block.timestamp + time);
        vm.warp(30 days);
        uint256 remaining = xMGN.periodFinish() - block.timestamp;
        uint256 leftover = remaining * xMGN.rewardRate();
        xMGN.issuanceRate(100 * 1e18);
        uint256 rr = (100 * 1e18 + leftover) / time;
        assertEq(xMGN.rewardRate(), rr);
    }

    function testMintOrDeposit() public {
        xMGN.deposit(100 * 1e18, alice);
        assertEq(xMGN.balanceOf(alice), 100 * 1e18);

        vm.prank(alice);
        xMGN.deposit(100 * 1e18, address(this));
        assertEq(xMGN.balanceOf(address(this)), 100 * 1e18);

        vm.prank(alice);
        mugen.transfer(bob, 100 * 1e18);
        vm.prank(bob);
        mugen.approve(address(xMGN), type(uint256).max);
        vm.prank(bob);
        xMGN.mint(100 * 1e18, bob);
        assertEq(xMGN.balanceOf(bob), 100 * 1e18);
    }

    function testWithdrawOrRedeem() public {
        vm.expectRevert("xMGN:M:ZERO_SHARES");
        xMGN.deposit(0, address(this));
        xMGN.deposit(100 * 1e18, alice);
        vm.prank(alice);
        xMGN.deposit(100 * 1e18, address(this));
        vm.prank(alice);
        mugen.transfer(bob, 100 * 1e18);
        vm.prank(bob);
        mugen.approve(address(xMGN), type(uint256).max);
        vm.prank(bob);
        xMGN.mint(100 * 1e18, bob);
        //
        xMGN.withdraw(100 * 1e18, address(this), address(this));
        assertEq(xMGN.balanceOf(address(this)), 0);
        assertEq(xMGN.totalSupply(), 200 * 1e18);
        assertEq(mugen.balanceOf(address(xMGN)), 200 * 1e18);
        //
        vm.prank(alice);
        xMGN.redeem(100 * 1e18, alice, alice);
        assertEq(xMGN.balanceOf(alice), 0);
        assertEq(xMGN.totalSupply(), 100 * 1e18);
        assertEq(mugen.balanceOf(address(xMGN)), 100 * 1e18);
        //
        vm.prank(bob);
        xMGN.redeem(100 * 1e18, bob, bob);
        assertEq(xMGN.balanceOf(alice), 0);
        assertEq(xMGN.totalSupply(), 0);
        assertEq(mugen.balanceOf(address(xMGN)), 0);
    }

    /**
     Rewards will be in eth and while not going above 184 (due to overflow)
     does not cover all possible scenerios,
     it does cover up until a deposit of around 2.45e37 eth. Or at current prices of eth around
     3.6e40 USD which I am quite comfortable with.
     */
    function testSingleRewardCalc(uint184 amount) public {
        vm.assume(amount > 0);
        vm.prank(alice);
        xMGN.deposit(100 * 1e18, alice);
        xMGN.issuanceRate(amount);
        vm.warp(30 days);
        vm.prank(alice);
        xMGN.withdraw(100 * 1e18, alice, alice);
    }

    function testMultipleRewards() public {
        xMGN.deposit(1000 * 1e18, address(this));
        vm.prank(alice);
        xMGN.deposit(1000 * 1e18, alice);
        xMGN.issuanceRate(10000 * 1e18);
        vm.warp(31 days);
        uint256 first = xMGN.earned(address(this));
        uint256 second = xMGN.earned(alice);
        xMGN.withdraw(1000 * 1e18, address(this), address(this));
        vm.prank(alice);
        xMGN.withdraw(1000 * 1e18, alice, alice);
        assertEq(first, second);
        assertGt(mock.balanceOf(alice), 5000 * 1e18 - 1e6); //Will always be a little bit of "dust" that does not get distributed
    }

    function testAllowance() public {
        xMGN.deposit(1000 * 1e18, address(this));
        vm.prank(alice);
        xMGN.deposit(1000 * 1e18, alice);
        xMGN.issuanceRate(10000 * 1e18);
        xMGN.increaseAllowance(alice, 1000 * 1e18);
        vm.warp(31 days);
        vm.prank(alice);
        xMGN.withdraw(1000 * 1e18, alice, address(this));
        assertEq(mock.balanceOf(alice), 0);
        assertGt(
            mock.balanceOf(address(this)),
            type(uint256).max - 6000 * 1e18
        );
        assertEq(xMGN.allowance(address(this), alice), 0);
    }
}
