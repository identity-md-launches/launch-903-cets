// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {Cets} from "../src/Cets.sol";

/// @dev Complements the deployment and basic ERC-20 tests with repeated-call and arithmetic edges.
/// forge-config: default.fuzz.runs = 1000
contract CetsEdgeTest is Test {
    uint256 private constant SUPPLY = 1_000_000_000 * 10 ** 18;
    address private constant ALICE = address(0xA11CE);
    address private constant BOB = address(0xB0B);
    address private constant SPENDER = address(0x5EED);
    Cets private token;

    function setUp() public {
        token = new Cets();
    }

    function test_oneBaseUnitCanRoundTripAndBeDelegated() public {
        assertTrue(token.transfer(ALICE, 1));
        vm.prank(ALICE);
        assertTrue(token.transfer(address(this), 1));
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(ALICE), 0);

        assertTrue(token.approve(SPENDER, 1));
        vm.prank(SPENDER);
        assertTrue(token.transferFrom(address(this), ALICE, 1));
        assertEq(token.balanceOf(address(this)), SUPPLY - 1);
        assertEq(token.balanceOf(ALICE), 1);
        assertEq(token.allowance(address(this), SPENDER), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_maximumAmountFailsEvenWithInfiniteApprovalOrSelfRecipient() public {
        assertTrue(token.approve(SPENDER, type(uint256).max));
        address[2] memory recipients = [ALICE, address(this)];
        bytes memory error = abi.encodeWithSelector(
            IERC20Errors.ERC20InsufficientBalance.selector, address(this), SUPPLY, type(uint256).max
        );
        for (uint256 i; i < recipients.length; ++i) {
            vm.expectRevert(error);
            token.transfer(recipients[i], type(uint256).max);
            vm.expectRevert(error);
            vm.prank(SPENDER);
            token.transferFrom(address(this), recipients[i], type(uint256).max);
        }
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(ALICE), 0);
        assertEq(token.allowance(address(this), SPENDER), type(uint256).max);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_maximumMinusOneAllowanceIsFinite() public {
        uint256 approved = type(uint256).max - 1;
        assertTrue(token.approve(SPENDER, approved));
        vm.startPrank(SPENDER);
        assertTrue(token.transferFrom(address(this), ALICE, 1));
        assertEq(token.allowance(address(this), SPENDER), approved - 1);
        assertTrue(token.transferFrom(address(this), BOB, SUPPLY - 1));
        vm.stopPrank();
        assertEq(token.allowance(address(this), SPENDER), approved - SUPPLY);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(ALICE), 1);
        assertEq(token.balanceOf(BOB), SUPPLY - 1);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_infiniteApprovalCanBeReplacedAndRevokedAfterSpending() public {
        assertTrue(token.approve(SPENDER, type(uint256).max));
        vm.prank(SPENDER);
        assertTrue(token.transferFrom(address(this), ALICE, 1));
        assertEq(token.allowance(address(this), SPENDER), type(uint256).max);

        assertTrue(token.approve(SPENDER, 2));
        assertEq(token.allowance(address(this), SPENDER), 2);
        vm.prank(SPENDER);
        assertTrue(token.transferFrom(address(this), ALICE, 2));
        assertEq(token.allowance(address(this), SPENDER), 0);

        assertTrue(token.approve(SPENDER, type(uint256).max));
        assertTrue(token.approve(SPENDER, 0));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, SPENDER, 0, 1));
        vm.prank(SPENDER);
        token.transferFrom(address(this), ALICE, 1);
        assertEq(token.allowance(address(this), SPENDER), 0);
        assertEq(token.balanceOf(ALICE), 3);
        assertEq(token.balanceOf(address(this)), SUPPLY - 3);
    }

    function test_exhaustedAllowanceDoesNotReturnWhenBalanceIsRefilled() public {
        assertTrue(token.transfer(ALICE, 7));
        vm.prank(ALICE);
        assertTrue(token.approve(SPENDER, 7));
        vm.prank(SPENDER);
        assertTrue(token.transferFrom(ALICE, BOB, 7));
        vm.prank(BOB);
        assertTrue(token.transfer(ALICE, 7));

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, SPENDER, 0, 1));
        vm.prank(SPENDER);
        token.transferFrom(ALICE, BOB, 1);
        assertEq(token.allowance(ALICE, SPENDER), 0);
        assertEq(token.balanceOf(ALICE), 7);
        assertEq(token.balanceOf(BOB), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_ownerAlsoNeedsApprovalForTransferFrom() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(this), 0, 1));
        token.transferFrom(address(this), ALICE, 1);

        assertTrue(token.approve(address(this), 2));
        assertTrue(token.transferFrom(address(this), ALICE, 1));
        assertTrue(token.transferFrom(address(this), address(this), 1));
        assertEq(token.allowance(address(this), address(this)), 0);
        assertEq(token.balanceOf(address(this)), SUPPLY - 1);
        assertEq(token.balanceOf(ALICE), 1);
    }

    function test_zeroRecipientStillRevertsWithZeroAmountAndInfiniteApproval() public {
        assertTrue(token.approve(SPENDER, type(uint256).max));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(SPENDER);
        token.transferFrom(address(this), address(0), 0);
        assertEq(token.allowance(address(this), SPENDER), type(uint256).max);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(address(0)), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_transferRoundTripRestoresBothBalances(uint256 aliceFunds, uint256 bobFunds, uint256 amount)
        public
    {
        aliceFunds = bound(aliceFunds, 0, SUPPLY);
        bobFunds = bound(bobFunds, 0, SUPPLY - aliceFunds);
        amount = bound(amount, 0, aliceFunds);
        assertTrue(token.transfer(ALICE, aliceFunds));
        assertTrue(token.transfer(BOB, bobFunds));
        vm.prank(ALICE);
        assertTrue(token.approve(SPENDER, type(uint256).max));

        vm.prank(ALICE);
        assertTrue(token.transfer(BOB, amount));
        assertEq(token.balanceOf(ALICE), aliceFunds - amount);
        assertEq(token.balanceOf(BOB), bobFunds + amount);
        vm.prank(BOB);
        assertTrue(token.transfer(ALICE, amount));
        assertEq(token.balanceOf(ALICE), aliceFunds);
        assertEq(token.balanceOf(BOB), bobFunds);
        assertEq(token.balanceOf(address(this)), SUPPLY - aliceFunds - bobFunds);
        assertEq(token.allowance(ALICE, SPENDER), type(uint256).max);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_splitSpendingCannotExceedOriginalApproval(uint256 approved, uint256 first) public {
        // Leave balance for a third spend so only the allowance can reject it.
        approved = bound(approved, 1, SUPPLY - 1);
        first = bound(first, 0, approved);
        assertTrue(token.approve(SPENDER, approved));
        vm.startPrank(SPENDER);
        assertTrue(token.transferFrom(address(this), ALICE, first));
        assertEq(token.allowance(address(this), SPENDER), approved - first);
        assertTrue(token.transferFrom(address(this), BOB, approved - first));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, SPENDER, 0, 1));
        token.transferFrom(address(this), BOB, 1);
        vm.stopPrank();
        assertEq(token.allowance(address(this), SPENDER), 0);
        assertEq(token.balanceOf(ALICE), first);
        assertEq(token.balanceOf(BOB), approved - first);
        assertEq(token.balanceOf(address(this)), SUPPLY - approved);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_failedDelegatedSpendPreservesApprovalForLaterUse(uint256 funds, uint256 requested) public {
        funds = bound(funds, 1, SUPPLY);
        requested = bound(requested, funds + 1, type(uint256).max - 1);
        assertTrue(token.transfer(ALICE, funds));
        vm.prank(ALICE);
        assertTrue(token.approve(SPENDER, requested));

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, ALICE, funds, requested));
        vm.prank(SPENDER);
        token.transferFrom(ALICE, BOB, requested);
        assertEq(token.allowance(ALICE, SPENDER), requested);
        assertEq(token.balanceOf(ALICE), funds);
        assertEq(token.balanceOf(BOB), 0);

        vm.prank(SPENDER);
        assertTrue(token.transferFrom(ALICE, BOB, funds));
        assertEq(token.allowance(ALICE, SPENDER), requested - funds);
        assertEq(token.balanceOf(ALICE), 0);
        assertEq(token.balanceOf(BOB), funds);
        assertEq(token.balanceOf(address(this)), SUPPLY - funds);
        assertEq(token.totalSupply(), SUPPLY);
    }
}
