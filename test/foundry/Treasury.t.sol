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
    MockERC20 usdc;
    MockERC20 testMock;
    NotMockAggregator feed;
    Mugen mugen;
    LZEndpointMock Endpoint;
    Treasury treasury;
    Communicator comms;
    address alice = address(0x1337);

    function setUp() public {
        mock = new MockDAI(type(uint256).max);
        usdc = new MockUSDC(type(uint256).max);
        testMock = new MockERC20("test", "tst", 24, type(uint256).max);
        feed = new NotMockAggregator(8, 1e8);
        Endpoint = new LZEndpointMock(1);
        mugen = new Mugen(address(Endpoint));
        comms = new Communicator(address(Endpoint));
        treasury = new Treasury(address(mugen), alice, address(this));
        treasury.addTokenInfo(mock, address(feed));
        comms.setTreasury(address(treasury));
        mock.approve(address(treasury), type(uint256).max);
        usdc.approve(address(treasury), type(uint256).max);
        testMock.approve(address(treasury), type(uint256).max);
        mugen.setMinter(address(treasury));
        treasury.setCommunicator(address(comms));
    }

    function testSetUp() public {
        assertEq(treasury.readSupply(), 1e18);
        assertEq(treasury.owner(), address(this));
        assertEq(treasury.treasury(), alice);
    }

    function testTreasuryDeposit(uint256 x) public {
        vm.assume(x > 100 * 1e18 && x < 4851651944097902779691068306);
        vm.expectRevert("Deposit must be more than 0");
        treasury.deposit(mock, 0);
        vm.expectRevert("less than min deposit");
        treasury.deposit(mock, 49 * 1e18);
        vm.expectRevert(Treasury.NotDepositable.selector);
        treasury.deposit(usdc, x);
        treasury.addTokenInfo(usdc, address(feed));
        uint256 expected = treasury.calculateContinuousMintReturn(x);
        treasury.deposit(mock, x);
        assertEq(mugen.totalSupply(), expected);
        assertEq(treasury.readSupply(), expected + 1e18);
        assertEq(mugen.balanceOf(address(this)), expected);
        assertEq(mock.balanceOf(alice), x);
        assertEq(treasury.valueDeposited(), x);
    }

    function testDecimals() public {
        treasury.addTokenInfo(usdc, address(feed));
        treasury.pricePerToken();
        uint256 expected = treasury.calculateContinuousMintReturn(1000 * 1e18);
        treasury.deposit(usdc, 1000 * 1e6);
        assertEq(mugen.totalSupply(), expected);
        assertEq(treasury.readSupply(), expected + 1e18);
        assertEq(mugen.balanceOf(address(this)), expected);
        assertEq(usdc.balanceOf(alice), 1000 * 1e6);
        assertEq(treasury.valueDeposited(), 1000 * 1e18);
    }

    function testDecimals2() public {
        treasury.addTokenInfo(testMock, address(feed));
        uint256 expected = treasury.calculateContinuousMintReturn(1000 * 1e18);
        treasury.deposit(testMock, 1000 * 1e24);
        assertEq(mugen.totalSupply(), expected);
        assertEq(treasury.readSupply(), expected + 1e18);
        assertEq(mugen.balanceOf(address(this)), expected);
        assertEq(testMock.balanceOf(alice), 1000 * 1e24);
        assertEq(treasury.valueDeposited(), 1000 * 1e18);
    }

    function testReceiveMessage(uint256 amount) public {
        vm.assume(amount > 0 && amount < 4851651944097902779691068306);
        vm.expectRevert(Treasury.NotCommunicator.selector);
        vm.prank(alice);
        treasury.receiveMessage(100 * 1e18);
        uint256 calculate = treasury.calculateContinuousMintReturn(amount);
        uint256 expected = comms.sendMessage(amount);
        assertEq(calculate, expected);
        assertEq(treasury.readSupply(), calculate + 1e18);
    }

    function testAddOrRemove() public {
        vm.expectRevert(Treasury.NotOwner.selector);
        vm.prank(alice);
        treasury.addTokenInfo(usdc, address(feed));
        treasury.addTokenInfo(usdc, address(feed));
        assertEq(treasury.checkDepositable(usdc), true);
        vm.expectRevert(Treasury.NotOwner.selector);
        vm.prank(alice);
        treasury.removeTokenInfo(usdc);
        treasury.removeTokenInfo(usdc);
        assertEq(treasury.checkDepositable(usdc), false);
    }

    function testSetComms() public {
        vm.expectRevert(Treasury.NotOwner.selector);
        vm.prank(alice);
        treasury.setCommunicator(address(comms));
    }

    //Go through this one again
    function testSetAndRemoveAdmin() public {
        vm.expectRevert("not the owner");
        vm.prank(alice);
        treasury.setAdministrator(alice);
        treasury.setAdministrator(alice);
        assertEq(treasury.administrator(), alice);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        treasury.removeAdmin();
        treasury.removeAdmin();
        assertEq(treasury.administrator(), address(0));
        assertEq(treasury.adminRemoved(), true);
        vm.expectRevert(Treasury.AdminRemoved.selector);
        treasury.setAdministrator(address(this));
        vm.expectRevert(Treasury.AdminRemoved.selector);
        treasury.setAdministrator(address(this));
    }

    function testCap() public {
        treasury.setCap(50000 * 1e18);
        treasury.deposit(mock, 50001 * 1e18);
        vm.expectRevert(Treasury.CapReached.selector);
        treasury.deposit(mock, 100 * 1e18);
    }

    function testAverage() public {
        treasury.setCap(10000000000 * 1e18);
        treasury.deposit(mock, 2000000000 * 1e18);
        treasury.deposit(mock, 2000000000 * 1e18);
        treasury.deposit(mock, 2000000000 * 1e18);
        treasury.deposit(mock, 2000000000 * 1e18);
        treasury.deposit(mock, 2000000000 * 1e18);
        mugen.totalSupply();
        treasury.pricePerToken();
        //Total supply of 2511885.451604671543066581
        //Price at 497.63
        //Market cap of 1.25 billion so 250 million dollar difference at 1 billion deposits

        //10 billion desposits
        //Total Supply of 15848930.937290280390442002
        //Pirce of 788.69
        //Marketcap of 12.5 billion so again about a 25% difference

        //If 75% are staked that puts it at around 11.886 million 25% apy on the treasury
        //would be a 26% return based on staking numbers and current
    }
}
