// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../contracts/Strategy/ArbitrumStrategies/GMXStrategy.sol";

contract GMXStrategyScript is Script {
    address gmx = address(0xA906F338CB21815cBc4Bc87ace9e68c87eF8d8F1);
    address weth = address(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        new GMXStrategy(gmx, weth);
    }
}
