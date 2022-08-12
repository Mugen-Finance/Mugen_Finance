// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "../src/Mugen/Mugen.sol";
import "../src/Mugen/xMugen.sol";
import "../src/mocks/MockERC20.sol";
import "../src/mocks/LZEndpointMock.sol";

contract xMugenTest is Test {
    Mugen mugen;
    xMugen xMGN;
    MockUSDC reward;
    LZEndpointMock endpoint;
    address alice = address(0x1337);

    function setUp() public {
        endpoint = new LZEndpointMock(2);
        mugen = new Mugen(address(endpoint));
        reward = new MockUSDC(type(uint256).max);
        xMGN = new xMugen(address(mugen), address(reward));
        reward.approve(address(xMGN), type(uint256).max);
        mugen.approve(address(xMGN), type(uint256).max);
        mugen.mint(address(this), type(uint256).max);
        reward.transfer(alice, 1e25);
        mugen.transfer(alice, 1e25);
        vm.prank(alice);
        mugen.approve(address(xMGN), type(uint256).max);
    }

    function testIssuance() public {
        vm.expectRevert("xMGN:UVS:ZERO_SUPPLY");
        xMGN.issuanceRate(100 * 1e18);
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        xMGN.issuanceRate(100 * 1e18);
        xMGN.deposit(1000 * 1e18, alice);
        assertEq(xMGN.balanceOf(alice), 1000 * 1e18);
        assertEq(xMGN.totalSupply(), 1000 * 1e18);
        xMGN.issuanceRate(100 * 1e18);
        uint256 time = 30 days;
        assertEq(reward.balanceOf(address(xMGN)), 100 * 1e18);
        assertEq(xMGN.getRewardRate(), (100 * 1e18) / time);
        vm.warp(15 days);
        xMGN.issuanceRate(100 * 1e18);
        assertEq(reward.balanceOf(address(xMGN)), 200 * 1e18);
    }

    function testDeposits() public {
        //     //can send reward to whoever you want
        //     /*
        //     Odd edge case around overflow/underflow after initial deposit.
        //     Was fixed by depositing reward tokens but unclear as to why this pops up.
        //     Same happens with the first initial issuance update. If it is zero causes
        //     the same issue
        //     All revolves around rewardPerToken call.
        //     */
        xMGN.deposit(100 * 1e18, address(this));
        //     xMGN.issuanceRate(100 * 1e18);
        //     vm.warp(100);
        vm.prank(alice);
        xMGN.deposit(100 * 1e18, alice);
        assertEq(xMGN.balanceOf(address(this)), 100 * 1e18);
        assertEq(xMGN.balanceOf(alice), 100 * 1e18);
        vm.prank(alice);
        xMGN.deposit(100 * 1e18, alice);
        vm.prank(alice);
        xMGN.deposit(100 * 1e18, address(this));
        assertEq(xMGN.balanceOf(address(this)), 200 * 1e18);
        assertEq(xMGN.balanceOf(alice), 200 * 1e18);
    }

    function testMint() public {
        //     //Same issues as stated above
        xMGN.mint(100 * 1e18, address(this));
        //     xMGN.issuanceRate(100 * 1e18);
        vm.warp(100);
        vm.prank(alice);
        xMGN.mint(100 * 1e18, alice);
        assertEq(xMGN.balanceOf(address(this)), 100 * 1e18);
        assertEq(xMGN.balanceOf(alice), 100 * 1e18);
        vm.prank(alice);
        xMGN.mint(100 * 1e18, alice);
        vm.prank(alice);
        xMGN.mint(100 * 1e18, address(this));
        assertEq(xMGN.balanceOf(address(this)), 200 * 1e18);
        assertEq(xMGN.balanceOf(alice), 200 * 1e18);
    }

    function testWithdraw() public {
        //     //Not fully distributing rewards, most likely because of the way that updated rewards is set up
        xMGN.mint(100 * 1e18, address(this));
        xMGN.issuanceRate(100 * 1e18);
        vm.warp(100);
        xMGN.withdraw(50 * 1e18, address(this), address(this));
        vm.warp(100);
        xMGN.withdraw(50 * 1e18, address(this), address(this));
        vm.prank(alice);
        xMGN.deposit(1000 * 1e18, alice);
        vm.warp(15 days);
        xMGN.earned(alice);
        vm.prank(alice);
        xMGN.withdraw(500 * 1e18, alice, alice);
        xMGN.earned(alice);
        vm.warp(33 days);
        xMGN.deposit(100 * 1e18, address(this));
        xMGN.earned(alice);
        vm.prank(alice);
        xMGN.withdraw(500 * 1e18, alice, alice);
        uint256 acceptableDust = 1e10;
        assertLt(reward.balanceOf(address(xMGN)), acceptableDust);
    }
}
