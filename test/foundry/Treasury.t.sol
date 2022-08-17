// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "../../contracts/Mugen/Communicator.sol";
import "../../contracts/Mugen/Treasury.sol";
import "../../contracts/mocks/LZEndpointMock.sol";
import "../../contracts/Mugen/Mugen.sol";
import "../../contracts/mocks/MockERC20.sol";
import "../../contracts/mocks/NotMockAggregator.sol";

contract TreasuryTest is Test {
    MockERC20 mock;
    NotMockAggregator feed;
    Mugen mugen;
    LZEndpointMock Endpoint;
    Treasury treasury;
    Communicator comms;
    address alice = address(0x1337);

    //retest treasury functions after changing mock feed

    function setUp() public {
        mock = new MockDAI(type(uint256).max);
        feed = new NotMockAggregator(6, 2e6);
        Endpoint = new LZEndpointMock(1);
        mugen = new Mugen(address(Endpoint));
        comms = new Communicator(address(Endpoint));
        treasury = new Treasury(address(mugen), alice, address(Endpoint));
        treasury.addTokenInfo(mock, address(feed));
        mock.approve(address(treasury), type(uint256).max);
        mugen.transferOwnership(address(treasury));
    }

    function testSetUp() public {
        assertEq(treasury.readSupply(), 1e18);
        assertEq(treasury.owner(), address(this));
        assertEq(treasury.treasury(), alice);
        assertEq(mugen.owner(), address(treasury));
    }

    function testCalculate() public {
        uint256 expected = treasury.calculateContinuousMintReturn(10000 * 1e18);
        assertEq(250389573978420943928, expected);
    }

    function testFeedDecimals() public {
        //Test with 18 decimals on the pricefeed
        treasury.deposit(mock, 100 * 1e18);
        mugen.totalSupply();
        //5.809483127522301301 total supply of mugen when feed is 18 decimals

        //Test results with 8 decimals on pricefeed
        //5.809483127522301301

        //Test results with 6 decimals on pricefeed
        //5.809483127522301301
    }
}
