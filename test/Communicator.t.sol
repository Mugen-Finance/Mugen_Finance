// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.0;

// import "forge-std/Test.sol";
// import "forge-std/Vm.sol";
// import "../src/Mugen/Communicator.sol";
// import "../src/Mugen/Treasury.sol";
// import "../src/mocks/LZEndpointMock.sol";
// import "../src/Mugen/Mugen.sol";
// import "../src/mocks/MockERC20.sol";
// import "../src/mocks/NotMockAggregator.sol";

// contract CommunicatorTest is Test {
//     MockERC20 mock;
//     NotMockAggregator feed;
//     Mugen mugen;
//     LZEndpointMock Endpoint;
//     Treasury treasury;
//     Communicator comms;
//     address alice = address(0x1337);

//     function setUp() public {
//         mock = new MockDAI(type(uint256).max);
//         feed = new NotMockAggregator(8, 100000000);
//         Endpoint = new LZEndpointMock(1);
//         mugen = new Mugen(address(Endpoint));
//         comms = new Communicator(address(Endpoint));
//         treasury = new Treasury(address(mugen), alice, address(this));
//         treasury.addTokenInfo(mock, address(feed));
//         mock.approve(address(treasury), type(uint256).max);
//         mugen.setMinter(address(treasury));
//     }

//     // function testMessage(uint200 amount) public {
//     //     vm.assume(amount > 0);
//     //     vm.assume(amount < 4851651944097902779691068306);
//     //     uint256 first = treasury.calculateContinuousMintReturn(amount);
//     //     treasury.setCommunicator(address(comms));
//     //     comms.setTreasury(address(treasury));
//     //     uint256 second = comms.sendMessage(amount);
//     //     assertEq(first, second);
//     // }

//     // function testDeposits(uint128 amount) public {
//     //     vm.assume(amount > 100 * 1e18);
//     //     vm.assume(amount < 4851651944097902779691068306);
//     //     uint256 predicted = treasury.calculateContinuousMintReturn(amount);
//     //     treasury.deposit(mock, amount);
//     //     uint256 actual = mugen.totalSupply();
//     //     assertEq(predicted, actual);
//     // }
//     //39.128885573036870855
//     //250.389573978420943928
//     //17011148.419142234939118780
// }
// //3,638,658,538,924,045,119,126,437,326
