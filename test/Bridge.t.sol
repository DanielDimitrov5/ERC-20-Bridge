// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";
import {BridgeCoin} from "src/BridgeCoin.sol";
import {Bridge} from "src/Bridge.sol";
import {DeployScript} from "script/Deploy.s.sol";
import {WERC20} from "src/WERC.sol";
import {IBridge} from "src/IBridge.sol";
import {console2} from "forge-std/console2.sol";

contract BridgeTest is Test {
    Bridge bridge;
    BridgeCoin token;

    bytes constant SIGNATURE =
        hex"7c4a32493653d40939102aa45d907bcb42f7bdd6a02df4817c852db3b136b42a6f41e0246ed87299cac0dc260f6d4d374d08472225183ce47d29a5db1e490e6d1b";

    function setUp() public {
        DeployScript script = new DeployScript();
        (bridge, token) = script.run(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266); // Anvil #1

        token.mint(address(this), 1000);
        token.approve(address(bridge), 1000);
    }

    function test_LockRevertsOnInvalidData() public {
        vm.expectRevert(abi.encodeWithSelector(Bridge.Bridge__InvalidAmount.selector, 0));
        bridge.lock(IBridge.LockData(address(1), 0, 1));

        vm.expectRevert(abi.encodeWithSelector(Bridge.Bridge__InvalidToken.selector));
        bridge.lock(IBridge.LockData(address(0), 1000, 1));

        vm.expectRevert(abi.encodeWithSelector(Bridge.Bridge__InvalidChainId.selector, 0));

        bridge.lock(IBridge.LockData(address(1), 1000, 0));
    }

    function test_Lock() public {
        bridge.lock(IBridge.LockData(address(token), 1000, 1));
        assertEq(token.balanceOf(address(bridge)), 1000);
    }

    function test_LockBurnsWrappedTokens() public {
        _mint_helper();

        WERC20 w = bridge.wrappedTokens(address(token));
        assertEq(w.balanceOf(address(this)), 1e18);

        bridge.lock(IBridge.LockData(address(token), 1e18, 1));
        assertEq(w.balanceOf(address(this)), 0);
    }

    function test_LockEmitsEvent() public {
        vm.expectEmit();

        emit Bridge.Lock(address(token), address(this), 1000, 1337, IBridge.WrapData("BridgeCoin", "BRC"));

        bridge.lock(IBridge.LockData(address(token), 1000, 1337));
    }

    function test_MintRevertsOnInvalidData() public {
        vm.expectRevert(abi.encodeWithSelector(Bridge.Bridge__InvalidToken.selector));
        bridge.mint(IBridge.MintData(address(0), address(this), 1000, 0, hex"", IBridge.WrapData("", "")));

        vm.expectRevert(abi.encodeWithSelector(Bridge.Bridge__InvalidRecepient.selector, address(0)));
        bridge.mint(IBridge.MintData(address(token), address(0), 1000, 0, hex"", IBridge.WrapData("", "")));

        vm.expectRevert(abi.encodeWithSelector(Bridge.Bridge__InvalidAmount.selector, 0));
        bridge.mint(IBridge.MintData(address(token), address(this), 0, 0, hex"", IBridge.WrapData("", "")));

        vm.expectRevert(abi.encodeWithSelector(Bridge.Bridge__InvalidNonce.selector, 5));
        bridge.mint(IBridge.MintData(address(token), address(this), 1000, 5, hex"", IBridge.WrapData("", "")));

        vm.expectRevert(abi.encodeWithSelector(Bridge.Bridge__InvalidSignature.selector));

        bytes memory fakeSignature =
            hex"7c4a32493653d40939102aa45d907bcb42f7bdd6a02df4817c852db3b136b42a6f41e0246ed87299cac0dc260f6d4d374d08472225183ce47d29a5db1e490e6d1b";

        bridge.mint(IBridge.MintData(address(token), address(this), 1000, 0, fakeSignature, IBridge.WrapData("", "")));
    }

    function test_MintRecover() external {
        _mint_helper();

        WERC20 w = bridge.wrappedTokens(address(token));

        assertEq(w.balanceOf(address(this)), 1e18);
        assertEq(bridge.nonces(address(this)), 1);
    }

    function test_MintEmitsEvents() external {
        vm.expectEmit(true, false, false, false);
        emit Bridge.TokenWrapped(address(token), address(0x1));

        vm.expectEmit(false, true, true, false);
        emit Bridge.Mint(address(0x1), address(this), 1e18);

        _mint_helper();
    }

    function test_BurnRevertsOnInvalidData() public {
        vm.expectRevert(abi.encodeWithSelector(Bridge.Bridge__InvalidToken.selector));
        bridge.burn(address(0), 1000);

        _mint_helper();

        vm.expectRevert(abi.encodeWithSelector(Bridge.Bridge__InvalidAmount.selector, 0));
        bridge.burn(address(token), 0);
    }

    function test_Burn() public {
        _mint_helper();

        WERC20 w = bridge.wrappedTokens(address(token));

        assertEq(w.balanceOf(address(this)), 1e18);

        bridge.burn(address(token), 1e18 / 2);

        assertEq(w.balanceOf(address(this)), 1e18 / 2);
    }

    function test_BurnEmitsEvent() public {
        _mint_helper();

        vm.expectEmit(true, true, true, false);
        emit Bridge.Burn(address(token), address(this), 1e18 / 2);

        bridge.burn(address(token), 1e18 / 2);
    }

    function _mint_helper() internal {
        bridge.mint(
            IBridge.MintData(
                address(token), address(this), 1e18, 0, SIGNATURE, IBridge.WrapData(token.name(), token.symbol())
            )
        );
    }
}
