pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "../src/Fundraising.sol";
import "../src/mocks/MockERC20.sol";

contract MugenTest is Test {
    Fundraiser fund;
    MockDAI dai;
    MockLUSD lusd;
    address alice = address(0x1337);

    function setUp() public {
        dai = new MockDAI(1e30);
        lusd = new MockLUSD(1e30);
        fund = new Fundraiser(address(dai), alice);
        dai.approve(address(fund), type(uint256).max);
        lusd.approve(address(fund), type(uint256).max);
    }

    function testInitialization() public {
        assertEq(fund.name(), "Mugen Debt Token");
        assertEq(fund.symbol(), "dtMugen");
        assertEq(fund.totalSupply(), 0);
        assertEq(fund.owner(), address(this));
    }

    //Check for when max funds are reached
    function testFundDeposit() public {
        fund.deposit(100 * 1e18);
        fund.deposit(1499900 * 1e18);
        assertEq(dai.balanceOf(alice), 1500000 * 1e18);
        assertEq(fund.totalSupply(), 4500000 * 1e18);
        assertEq(fund.balanceOf(address(this)), 4500000 * 1e18);
    }

    function testPayDebt() public {
        fund.deposit(500 * 1e18);
        fund.payDebt(300 * 1e18);
        assertEq(dai.balanceOf(address(fund)), 300 * 1e18);
    }

    function testClaimPayment() public {
        fund.deposit(100000 * 1e18);
        fund.payDebt(100000 * 1e18);
        vm.warp(100);
        uint256 newSupply = fund.totalSupply() - fund.earned(address(this));
        fund.claimPayment();
        vm.warp(100);
        vm.expectRevert("Still in Cooldown");
        fund.claimPayment();
        assertEq(fund.totalSupply(), newSupply);
        fund.payDebt(100000 * 1e18);
        vm.warp(8 days);
        fund.claimPayment();
    }

    function testRemaininDebt() public {}
}
