// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "../src/Mugen.sol";
import "../src/xMugen.sol";
import "../src/mocks/MockERC20.sol";
import "../src/mocks/LZEndpointMock.sol";

contract xMugenTest is Test {
    Mugen mugen;
    xMugen xMGN;
    MockUSDC reward;
    LZEndpointMock endpoint;

    function setUp() public {
        endpoint = new LZEndpointMock(2);
        mugen = new Mugen(address(endpoint));
        reward = new MockUSDC(type(uint256).max);
        xMGN = new xMugen(address(mugen), address(reward));
        reward.approve(address(xMGN), type(uint256).max);
        mugen.approve(address(xMGN), type(uint256).max);
        mugen.mint(address(this), type(uint256).max);
    }

    function testIssuance() public {
        xMGN.deposit(100, address(this));
        xMGN.issuanceRate(100000 * 1e18, 200000);
        uint256 rr = (100000 * 1e18) / 200000;
        uint256 time = block.timestamp + 200000;
        assertEq(xMGN.checkVestingEnd(), time);
        assertEq(xMGN.getRewardRate(), rr);
    }

    function testDeposit() public {
        xMGN.deposit(100, address(this));
        assertEq(mugen.balanceOf(address(xMGN)), 100);
        assertEq(xMGN.balanceOf(address(this)), 100);
        assertEq(xMGN.totalSupply(), 100);
        xMGN.mint(100, address(this));
        assertEq(mugen.balanceOf(address(xMGN)), 200);
        assertEq(xMGN.balanceOf(address(this)), 200);
        assertEq(xMGN.totalSupply(), 200);
    }

    function testWithdraw() public {
        xMGN.deposit(100, address(this));
        xMGN.withdraw(100, address(this), address(this));
        assertEq(mugen.balanceOf(address(xMGN)), 0);
        assertEq(xMGN.totalSupply(), 0);
        xMGN.deposit(100, address(this));
        xMGN.redeem(100, address(this), address(this));
        assertEq(mugen.balanceOf(address(xMGN)), 0);
        assertEq(xMGN.totalSupply(), 0);
    }

    function testAccounting(uint176 amount) public {
        vm.assume(amount > 1e18);
        xMGN.mint(amount, address(this));
        xMGN.issuanceRate(amount, 200000);
        vm.warp(100000);
        xMGN.earned(address(this));
        uint256 quarter = (amount) / 2;
        xMGN.withdraw(quarter, address(this), address(this));
    }
}
