// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "../src/Mugen.sol";

contract MugenTest is Test {
    Mugen mugen;
    address alice = address(0x1337);

    function setUp() public {
        mugen = new Mugen();
    }

    function testMint() public {
        mugen.mint(msg.sender, 100);
        uint256 expect = 100;
        assertEq(mugen.totalSupply(), expect);
        assertEq(mugen.balanceOf(msg.sender), expect);
    }

    function testTransferOwner() public {
        mugen.transferOwnership(alice);
        assertEq(mugen.owner(), alice);
        vm.expectRevert("Ownable: caller is not the owner");
        mugen.mint(alice, 100);
    }
}
