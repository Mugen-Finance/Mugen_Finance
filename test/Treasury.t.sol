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

    MockERC20 USDC;

    function setUp() public {}
}
