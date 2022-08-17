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
        mock = new MockUSDC(type(uint256).max);
        EndPoint = new LZEndpointMock(1);
        mugen = new Mugen(address(EndPoint));
        mugen.mint(address(this), type(uint104).max);
        mugen.transfer(alice, 1000 * 1e18);
        xMGN = new xMugen(address(mugen), address(mock));
        mock.approve(address(xMGN), type(uint256).max);
        mugen.approve(address(xMGN), type(uint256).max);
        vm.prank(alice);
        mugen.approve(address(xMGN), type(uint256).max);
    }

    function testIssuance(uint256 amount) public {
        vm.assume(amount > 1e18);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        xMGN.issuanceRate(100);
        vm.expectRevert("xMGN:UVS:ZERO_SUPPLY");
        xMGN.issuanceRate(amount);
        xMGN.deposit(100, address(this));
        xMGN.issuanceRate(amount);
        uint256 time = 30 days;
        assertEq(xMGN.getRewardRate(), amount / time);
        assertEq(mugen.balanceOf(address(xMGN)), 100);
        assertEq(xMGN.totalSupply(), 100);
        assertEq(xMGN.balanceOf(address(this)), 100);
    }

    function testReceiver() public {
        xMGN.deposit(100 * 1e18, alice);
        xMGN.issuanceRate(10000000 * 1e18);
        vm.warp(20 days);
        vm.prank(alice);
        xMGN.withdraw(100 * 1e18, alice, alice);
    }
}
