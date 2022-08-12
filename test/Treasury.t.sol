// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "../src/Mugen/Mugen.sol";
import "../src/Mugen/Treasury.sol";
import "../src/mocks/MockERC20.sol";
import "../src/mocks/LZEndpointMock.sol";
import "../src/mocks/NotMockAggregator.sol";

contract TreasuryTest is Test {
    NotMockAggregator assetMock;
    NotMockAggregator usdcMock;
    LZEndpointMock endpoint;
    Treasury treasury;
    Mugen mugen;
    MockERC20 asset;
    MockERC20 USDC;
    address alice = address(0x1337);
    uint16 srcChainId = 1;

    function setUp() public {
        asset = new MockLUSD(1e30);
        USDC = new MockUSDC(1e30);
        assetMock = new NotMockAggregator(8, 1e8);
        usdcMock = new NotMockAggregator(8, 1e8);
        endpoint = new LZEndpointMock(srcChainId);
        mugen = new Mugen(address(endpoint));
        treasury = new Treasury(address(mugen), alice, address(endpoint));
        USDC.approve(address(treasury), type(uint256).max);
        asset.approve(address(treasury), type(uint256).max);
        mugen.mint(address(this), 1e18);
        mugen.transferOwnership(address(treasury));
        treasury.addTokenInfo(USDC, address(usdcMock));
        treasury.addTokenInfo(asset, address(assetMock));
    }

    function testSingleDeposit() public {
        treasury.deposit(asset, 10000 * 1e18);
        treasury.deposit(asset, 10000 * 1e18);
        treasury.deposit(asset, 10000 * 1e18);
        mugen.totalSupply();
    }

    function testBig() public {
        treasury.deposit(asset, 30000 * 1e18);

        mugen.totalSupply();
    }

    function testManySmall() public {
        treasury.deposit(asset, 2000 * 1e18);
        treasury.deposit(asset, 2000 * 1e18);
        treasury.deposit(asset, 2000 * 1e18);
        treasury.deposit(asset, 2000 * 1e18);
        treasury.deposit(asset, 2000 * 1e18);
        treasury.deposit(asset, 2000 * 1e18);
        treasury.deposit(asset, 2000 * 1e18);
        treasury.deposit(asset, 2000 * 1e18);
        treasury.deposit(asset, 2000 * 1e18);
        treasury.deposit(asset, 2000 * 1e18);
        treasury.deposit(asset, 2000 * 1e18);
        treasury.deposit(asset, 2000 * 1e18);
        treasury.deposit(asset, 2000 * 1e18);
        treasury.deposit(asset, 2000 * 1e18);
        treasury.deposit(asset, 2000 * 1e18);
        mugen.totalSupply();
    }
}
