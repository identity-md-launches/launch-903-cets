// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Cets} from "../src/Cets.sol";

/// @dev All transfers stay within a closed set so conservation can be checked after each action.
contract CetsHandler is Test {
    Cets public immutable token;
    address[4] public actors = [address(0xA11CE), address(0xB0B), address(0xCAFE), address(0xD00D)];

    constructor(Cets token_) {
        token = token_;
    }

    function transfer(uint256 fromSeed, uint256 toSeed, uint256 amount) external {
        address from = actors[fromSeed % actors.length];
        address to = actors[toSeed % actors.length];
        amount = bound(amount, 0, token.balanceOf(from));
        vm.prank(from);
        assertTrue(token.transfer(to, amount));
    }

    function approve(uint256 ownerSeed, uint256 spenderSeed, uint256 amount) external {
        address owner = actors[ownerSeed % actors.length];
        address spender = actors[spenderSeed % actors.length];
        vm.prank(owner);
        assertTrue(token.approve(spender, amount));
        assertEq(token.allowance(owner, spender), amount);
    }

    function transferFrom(uint256 ownerSeed, uint256 spenderSeed, uint256 toSeed, uint256 amount) external {
        address owner = actors[ownerSeed % actors.length];
        address spender = actors[spenderSeed % actors.length];
        address to = actors[toSeed % actors.length];
        uint256 approved = token.allowance(owner, spender);
        uint256 balance = token.balanceOf(owner);
        amount = bound(amount, 0, approved < balance ? approved : balance);
        vm.prank(spender);
        assertTrue(token.transferFrom(owner, to, amount));
        assertEq(token.allowance(owner, spender), approved == type(uint256).max ? approved : approved - amount);
    }
}

contract CetsInvariantTest is StdInvariant, Test {
    uint256 private constant SUPPLY = 1_000_000_000_000_000_000_000_000_000;
    Cets private token;
    CetsHandler private handler;

    function setUp() public {
        token = new Cets();
        handler = new CetsHandler(token);
        for (uint256 i; i < 4; ++i) {
            assertTrue(token.transfer(handler.actors(i), SUPPLY / 4));
        }

        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = CetsHandler.transfer.selector;
        selectors[1] = CetsHandler.approve.selector;
        selectors[2] = CetsHandler.transferFrom.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    function invariant_supplyIsAlwaysFixed() public view {
        assertEq(token.totalSupply(), SUPPLY);
    }

    function invariant_allTokensRemainAccountedFor() public view {
        uint256 balances;
        for (uint256 i; i < 4; ++i) {
            balances += token.balanceOf(handler.actors(i));
        }
        assertEq(balances, SUPPLY);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(address(handler)), 0);
        assertEq(token.balanceOf(address(token)), 0);
        assertEq(token.balanceOf(address(0)), 0);
    }
}
