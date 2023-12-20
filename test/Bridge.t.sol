// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {BridgeCoin} from "src/BridgeCoin.sol";
import {Bridge} from "src/Bridge.sol";
import {DeployScript} from "script/Deploy.s.sol";

contract BridgeTest is Test {
    Bridge bridge;
    BridgeCoin token;

    function setUp() public {
        DeployScript script = new DeployScript();
        (bridge, token) = script.run();
        
        token.mint(address(this), 1000);
        token.approve(address(bridge), 1000);
    }

    function test_RevertsOnInvalidData() public {
        vm.expectRevert(
            abi.encodeWithSelector(Bridge.Bridge__InvalidAmount.selector, 0)    
        );
        bridge.lock(address(1), 0, 1);

        vm.expectRevert(
            abi.encodeWithSelector(Bridge.Bridge__InvalidToken.selector)    
        );
        bridge.lock(address(0), 1000, 1);

        vm.expectRevert(
            abi.encodeWithSelector(Bridge.Bridge__InvalidChainId.selector, 0)    
        );

        bridge.lock(address(1), 1000, 0);
    }

    function test_Lock() public {
        bridge.lock(address(token), 1000, 1);
        assertEq(token.balanceOf(address(bridge)), 1000);
    }

    function test_LockEmitsEvent() public {
        vm.expectEmit();

        emit Bridge.Lock(address(token), address(this), 1000, 1337);

        bridge.lock(address(token), 1000, 1337);
    }
}
