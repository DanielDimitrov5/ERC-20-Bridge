// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {BridgeCoin} from "src/BridgeCoin.sol";
import {Bridge} from "src/Bridge.sol";
import {DeployScript} from "script/Deploy.s.sol";
import {WERC20} from "src/WERC.sol";

contract BridgeTest is Test {
    Bridge bridge;
    BridgeCoin token;

    function setUp() public {
        DeployScript script = new DeployScript();
        (bridge, token) = script.run(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);

        token.mint(address(this), 1000);
        token.approve(address(bridge), 1000);
    }

    function test_RevertsOnInvalidData() public {
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

    function test_mint_recover() external {
        bytes memory signature =
            hex"54ccad3ddac5ebfde477ad223d50a16e1e8d1b4e3d61ce36b5f1729a1dea97f37a4dc78d45ae00524d9203295023b86d8476293959846aa3b43212531ffbb5731c";
        bridge.mint(address(token), 1e18, address(this), signature);

        WERC20 w = bridge.wrappedTokens(address(token));

        assertEq(w.balanceOf(address(this)), 1e18);
    }
}
