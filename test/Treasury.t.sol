// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "../src/Mugen.sol";
import "../src/Treasury.sol";
import "../src/mocks/MockERC20.sol";

contract TreasuryTest is Test {
    Treasury treasury;
    Mugen mugen;
    MockERC20 asset;

    function setUp() public {
        mugen = new Mugen();
        treasury = new Treasury(address(mugen), msg.sender);
        mugen.transferOwnership(address(treasury));
        asset = new MockDAI(1e24);
    }

    function test() public {}
}
