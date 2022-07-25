// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "../src/Mugen.sol";
import "../src/xMugen.sol";
import "../src/mocks/MockERC20.sol";

contract xMugenTest is Test {
    Mugen mugen;
    xMugen xMGN;
    MockUSDC reward;

    function setUp() public {
        mugen = new Mugen();
        reward = new MockUSDC(1000000 * 1e18);
        xMGN = new xMugen(address(mugen), address(reward), address(this));
        mugen.approve(address(xMGN), type(uint256).max);
        reward.approve(address(xMGN), type(uint256).max);
    }
}
