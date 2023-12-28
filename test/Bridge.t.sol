// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";
import {BridgeCoin} from "test/MockTokens/BridgeCoin.sol";
import {Bridge} from "src/Bridge.sol";
import {DeployScript} from "script/Deploy.s.sol";
import {WERC20} from "src/WERC20.sol";
import {IBridge} from "src/IBridge.sol";
import {console2} from "forge-std/console2.sol";

contract BridgeTest is Test {
    Bridge bridge;
    BridgeCoin token;

    bytes constant MINT_SIGNATURE =
        hex"7c4a32493653d40939102aa45d907bcb42f7bdd6a02df4817c852db3b136b42a6f41e0246ed87299cac0dc260f6d4d374d08472225183ce47d29a5db1e490e6d1b";

    bytes constant RELEASE_SIGNATURE = hex'92833aec8527889f2355ebcd1b84739ceb92979e381dc1fe354abff8caedd37c7c13ca851eeba659bc6c7a221153ef7bcae39894d28c3c16d596da4bacf751481c';

    function setUp() public {
        DeployScript script = new DeployScript();
        (bridge, token) = script.run(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266); // Anvil #1

        token.mint(address(this), 1e18);
        token.approve(address(bridge), 1e18);
    }

    function test_LockRevertsOnInvalidData() public {
        vm.expectRevert(abi.encodeWithSelector(Bridge.Bridge__InvalidAmount.selector, 0));
        bridge.lock(IBridge.LockData(address(1), 0, 1));

        vm.expectRevert(abi.encodeWithSelector(Bridge.Bridge__InvalidToken.selector));
        bridge.lock(IBridge.LockData(address(0), 1000, 1));

        vm.expectRevert(abi.encodeWithSelector(Bridge.Bridge__InvalidChainId.selector, 0));

        bridge.lock(IBridge.LockData(address(1), 1000, 0));
    }

    function test_LockLocksAssets() public {
        bridge.lock(IBridge.LockData(address(token), 1000, 1));
        assertEq(token.balanceOf(address(bridge)), 1000);
    }

    function test_LockBurnsWrappedTokens() public {
        _mint_helper();

        WERC20 w = bridge.wrappedTokens(address(token));
        w.approve(address(bridge), 1e18);
        assertEq(w.balanceOf(address(this)), 1e18);

        bridge.lock(IBridge.LockData(address(w), 1e18, 1));
        assertEq(w.balanceOf(address(this)), 0);
    }

    function test_LockUpdatesUserBalances() public {
        bridge.lock(IBridge.LockData(address(token), 1000, 1));
        assertEq(bridge.balances(address(this), address(token)), 1000);
    }  

    function test_LockEmitsEvent() public {
        vm.expectEmit();

        emit Bridge.Lock(address(token), address(this), 1000, 1337, IBridge.WrapData("BridgeCoin", "BRC"));

        bridge.lock(IBridge.LockData(address(token), 1000, 1337));
    }

    function test_MintRevertsOnInvalidData() public {
        vm.expectRevert(abi.encodeWithSelector(Bridge.Bridge__InvalidToken.selector));
        bridge.mint(IBridge.MintData(address(0), address(this), 1000, 0, hex"", 1,IBridge.WrapData("", "")));

        vm.expectRevert(abi.encodeWithSelector(Bridge.Bridge__InvalidRecepient.selector, address(0)));
        bridge.mint(IBridge.MintData(address(token), address(0), 1000, 0, hex"", 1,IBridge.WrapData("", "")));

        vm.expectRevert(abi.encodeWithSelector(Bridge.Bridge__InvalidAmount.selector, 0));
        bridge.mint(IBridge.MintData(address(token), address(this), 0, 0, hex"", 1,IBridge.WrapData("", "")));

        vm.expectRevert(abi.encodeWithSelector(Bridge.Bridge__InvalidNonce.selector, 5));
        bridge.mint(IBridge.MintData(address(token), address(this), 1000, 5, hex"", 1,IBridge.WrapData("", "")));

        vm.expectRevert(abi.encodeWithSelector(Bridge.Bridge__InvalidSignature.selector));

        bytes memory fakeSignature =
            hex"350b8dac6767f3a128eb8d417688134816c3bc4ae285c81a61110e25ff6aff2a45b6c5b29205e10284e93a2997c14506cde233298f1b4212454b2cded9ccef1b1c";

        bridge.mint(IBridge.MintData(address(token), address(this), 1000, 0, fakeSignature, 1,IBridge.WrapData("", "")));
    }

    function test_MintMintsTokens() external {
        _mint_helper();

        WERC20 w = bridge.wrappedTokens(address(token));

        assertEq(w.balanceOf(address(this)), 1e18);
        assertEq(bridge.nonces(address(this)), 1);
    }

    function test_MintUpdatesUserBalances() external {
        _mint_helper();

        assertEq(bridge.balances(address(this), address(token)), 1e18);
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

    function test_BurnUpdatesUserBalances() public {
        _mint_helper();

        bridge.burn(address(token), 1e18 / 2);

        assertEq(bridge.balances(address(this), address(token)), 1e18 / 2);
    }

    function test_BurnEmitsEvent() public {
        _mint_helper();

        vm.expectEmit(true, true, true, false);
        emit Bridge.Burn(address(token), address(this), 1e18 / 2);

        bridge.burn(address(token), 1e18 / 2);
    }

    function test_ReleaseRevertsOnInvalidData() public {
        vm.expectRevert(abi.encodeWithSelector(Bridge.Bridge__InvalidToken.selector));
        bridge.release(IBridge.ReleaseData(address(0), address(this), 1000, 0, hex""));

        vm.expectRevert(abi.encodeWithSelector(Bridge.Bridge__InvalidRecepient.selector, address(0)));
        bridge.release(IBridge.ReleaseData(address(token), address(0), 1000, 0, hex""));

        _lock_helper();
        uint256 amount = 1e18 + 1;
        vm.expectRevert(abi.encodeWithSelector(Bridge.Bridge__InvalidAmount.selector, amount));
        bridge.release(IBridge.ReleaseData(address(token), address(this), amount, 0, hex""));

        vm.expectRevert(abi.encodeWithSelector(Bridge.Bridge__InvalidNonce.selector, 5));
        bridge.release(IBridge.ReleaseData(address(token), address(this), 1000, 5, hex""));

        vm.expectRevert(abi.encodeWithSelector(Bridge.Bridge__InvalidSignature.selector));

        bytes memory fakeSignature =
            hex"350b8dac6767f3a128eb8d417688134816c3bc4ae285c81a61110e25ff6aff2a45b6c5b29205e10284e93a2997c14506cde233298f1b4212454b2cded9ccef1b1c";

        bridge.release(IBridge.ReleaseData(address(token), address(this), 1e18, 0, fakeSignature));
    }

    function test_ReleaseRecover() external {
        _lock_helper();
        bridge.release(IBridge.ReleaseData(address(token), address(this), 1e18, 0, RELEASE_SIGNATURE));
    }

    function test_ReleaseReleasesAssets() external {
        _lock_helper();

        assertEq(token.balanceOf(address(this)), 0);
        assertEq(bridge.balances(address(this), address(token)), 1e18);

        uint nonce = bridge.nonces(address(this));

        bridge.release(IBridge.ReleaseData(address(token), address(this), 1e18, 0, RELEASE_SIGNATURE));

        assertEq(token.balanceOf(address(this)), 1e18);
        assertEq(bridge.balances(address(this), address(token)), 0);
        assertEq(bridge.nonces(address(this)), nonce + 1);
    }

    function test_ReleaseEmitsEvent() external {
        _lock_helper();

        vm.expectEmit(true, true, false, false);
        emit Bridge.Release(address(token), address(this), 1e18);

        bridge.release(IBridge.ReleaseData(address(token), address(this), 1e18, 0, RELEASE_SIGNATURE));
    }

    function _lock_helper() internal {
        bridge.lock(IBridge.LockData(address(token), 1e18, 1));
    }

    function _mint_helper() internal {
        bridge.mint(
            IBridge.MintData(
                address(token), address(this), 1e18, 0, MINT_SIGNATURE, 1,IBridge.WrapData(token.name(), token.symbol())
            )
        );
    }
}
