// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";
import {BridgeCoin} from "src/BridgeCoin.sol";
import {Bridge} from "src/Bridge.sol";
import {DeployScript} from "script/Deploy.s.sol";
import {WERC20} from "src/WERC.sol";

contract BridgeTest is Test {
    Bridge bridge;
    BridgeCoin token;

    function setUp() public {
        DeployScript script = new DeployScript();
        (bridge, token) = script.run(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266); // Anvil #1

        token.mint(address(this), 1000);
        token.approve(address(bridge), 1000);
    }

    function test_LockRevertsOnInvalidData() public {
        vm.expectRevert(abi.encodeWithSelector(Bridge.Bridge__InvalidAmount.selector, 0));
        bridge.lock(address(1), 0, 1);

        vm.expectRevert(abi.encodeWithSelector(Bridge.Bridge__InvalidToken.selector));
        bridge.lock(address(0), 1000, 1);

        vm.expectRevert(abi.encodeWithSelector(Bridge.Bridge__InvalidChainId.selector, 0));

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

    function test_MintRevertsOnInvalidData() public {
        vm.expectRevert(abi.encodeWithSelector(Bridge.Bridge__InvalidToken.selector));
        bridge.mint(address(0), 1000, address(this), 0, hex"");

        vm.expectRevert(abi.encodeWithSelector(Bridge.Bridge__InvalidRecepient.selector, address(0)));
        bridge.mint(address(token), 1000, address(0), 0, hex"");

        vm.expectRevert(abi.encodeWithSelector(Bridge.Bridge__InvalidAmount.selector, 0));
        bridge.mint(address(token), 0, address(this), 0, hex"");
    }

    function test_mint_recover() external {
        bytes memory signature =
            hex"7c4a32493653d40939102aa45d907bcb42f7bdd6a02df4817c852db3b136b42a6f41e0246ed87299cac0dc260f6d4d374d08472225183ce47d29a5db1e490e6d1b";
        bridge.mint(address(token), 1e18, address(this), 0, signature);

        WERC20 w = bridge.wrappedTokens(address(token));

        assertEq(w.balanceOf(address(this)), 1e18);
    }
}
