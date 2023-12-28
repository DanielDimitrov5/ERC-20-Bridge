// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script} from "forge-std/Script.sol";
import {Bridge} from "src/Bridge.sol";
import {BridgeCoin} from "test/MockTokens/BridgeCoin.sol";

contract DeployScript is Script {
    function run(address admin) public returns (Bridge bridge, BridgeCoin token) {
        vm.startBroadcast();
        bridge = new Bridge(admin);
        token = new BridgeCoin();
        vm.stopBroadcast();
    }
}