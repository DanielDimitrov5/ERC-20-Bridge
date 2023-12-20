// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script} from "forge-std/Script.sol";
import {Bridge} from "src/Bridge.sol";
import {BridgeCoin} from "src/BridgeCoin.sol";

contract DeployScript is Script {
    function run() public returns (Bridge bridge, BridgeCoin token) {
        vm.startBroadcast();
        bridge = new Bridge();
        token = new BridgeCoin();
        vm.stopBroadcast();
    }
}
