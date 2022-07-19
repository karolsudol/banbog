// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "ds-test/test.sol";
import { RecurringPayments, PaymentStructures } from "src/RecurringPayments.sol";
import { ERC20PresetFixedSupply } from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";

interface Vm {
    function warp(uint256 x) external;
    function prank(address addr) external;
}

contract RecurringPaymentsTest is DSTest {
    RecurringPayments payments;
    ERC20PresetFixedSupply token;
    RecurringPayments bogey;

    address prankster = address(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    Vm vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        payments = new RecurringPayments();
        bogey = new RecurringPayments();
        token = new ERC20PresetFixedSupply("Test", "TST", 10000000000000, address(this));
    }

    function _createPlan(uint256 numIntervals, uint256 amountPerInterval, uint256 intervalLength) internal {
        token.approve(address(payments), numIntervals * amountPerInterval);
        payments.createPaymentPlan(address(bogey), address(token), amountPerInterval, numIntervals, intervalLength);
    }

    function testFailCreateNoApproval() public {
        // Test trying to create a payment plan without approving the full amount
        payments.createPaymentPlan(address(this), address(token), 1000, 5, 1 days);
    }

    function testCreatePlan() public {
        uint256 numIntervals = 5;
        uint256 amountPerInterval = 1000;
        uint256 intervalLength = 1 days;
        _createPlan(numIntervals, amountPerInterval, intervalLength);

        PaymentStructures.PaymentSchedule memory plan = payments.getPaymentDetails(1);
        assert(plan.totalIntervals == numIntervals);
        assert(plan.amountPerInterval == amountPerInterval);
        assert(plan.nextTransferOn > block.timestamp);
    }

    function testCreatePlanWithFuzzing(uint256 intervalLength) public {
        uint256 numIntervals = 5;
        uint256 amountPerInterval = 1000;
        _createPlan(numIntervals, amountPerInterval, intervalLength);
    }

    function testFulfillPlanWithFuzzing() public {
        uint256 intervalLength = 10000;
        uint256 numIntervals = 5;
        uint256 amountPerInterval = 1000;
        _createPlan(numIntervals, amountPerInterval, intervalLength);
        vm.warp(block.timestamp + intervalLength + 1);
        vm.prank(prankster);

        uint256 balanceBefore = token.balanceOf(address(this));
        payments.runInterval(1);
        uint256 balanceAfter = token.balanceOf(address(this));
        uint256 bogeyBalance = token.balanceOf(address(bogey));
        uint256 fee = amountPerInterval * payments.callerFeeBips() / payments.BIPS_DENOMINATOR();

        assert(balanceBefore > balanceAfter);
        assert(bogeyBalance == (amountPerInterval - fee));
        assert(balanceBefore == (balanceAfter + amountPerInterval));
    }

}