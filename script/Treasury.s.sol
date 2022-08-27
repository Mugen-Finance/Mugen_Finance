// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "forge-std/Script.sol";
import "../../contracts/Mugen/Communicator.sol";
import "../../contracts/Mugen/Treasury.sol";
import "../../contracts/mocks/LZEndpointMock.sol";
import "../../contracts/Mugen/Mugen.sol";
import "../../contracts/mocks/MockERC20.sol";
import "../../contracts/mocks/NotMockAggregator.sol";

contract TreasuryScript is Script {
    MockERC20 mock;
    MockERC20 usdc;
    NotMockAggregator feed;
    Mugen mugen;
    LZEndpointMock Endpoint;
    Treasury treasury;
    Communicator comms;
    address alice = address(0x1337);

    function setUp() public {
        mock = new MockDAI(type(uint256).max);
        usdc = new MockUSDC(type(uint256).max);
        feed = new NotMockAggregator(8, 1e8);
        Endpoint = new LZEndpointMock(1);
        mugen = new Mugen(address(Endpoint));
        comms = new Communicator(address(Endpoint));
        treasury = new Treasury(address(mugen), alice, address(this));
        //treasury.addTokenInfo(address(mock), address(feed));
        comms.setTreasury(address(treasury));
        mock.approve(address(treasury), type(uint256).max);
        usdc.approve(address(treasury), type(uint256).max);
        mugen.setMinter(address(treasury));
        treasury.setCommunicator(address(comms));
    }

    function run() public {
        vm.startBroadcast();
        mock = new MockDAI(type(uint256).max);
        usdc = new MockUSDC(type(uint256).max);
        feed = new NotMockAggregator(8, 1e8);
        Endpoint = new LZEndpointMock(1);
        mugen = new Mugen(address(Endpoint));
        comms = new Communicator(address(Endpoint));
        treasury = new Treasury(address(mugen), alice, address(this));
    }
}
