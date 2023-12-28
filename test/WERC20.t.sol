// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";
import {WERC20} from "src/WERC20.sol";

contract WERC20Test is Test {
    WERC20 werc;

    function setUp() public {
        werc = new WERC20("Wrapped Ether", "WETH", address(1), 1);
    }

    function test_WERC20Ctor() public {
        assertEq(werc.name(), "Wrapped Ether");
        assertEq(werc.symbol(), "WETH");
        assertEq(werc.UNDERLYING_TOKEN(), address(1));
        assertEq(werc.SOURCE_CHAIN_ID(), 1);
    }

    function test_MintOnlyOwner() public {
        vm.expectRevert();
        vm.prank(address(0x1));
        werc.mint(address(this), 1000);
    }

    function test_Mint() public {
        werc.mint(address(this), 1000);
        assertEq(werc.balanceOf(address(this)), 1000);
    }

    function test_BurnOnlyOwner() public {
        vm.expectRevert();
        vm.prank(address(0x1));
        werc.burn(address(this), 1000);
    }

    function test_Burn() public {
        werc.mint(address(this), 1000);
        werc.burn(address(this), 1000);
        assertEq(werc.balanceOf(address(this)), 0);
    }
}