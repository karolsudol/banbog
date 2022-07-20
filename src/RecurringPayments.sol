// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";


/**
 * @title PaymentStructures
 * @notice 
 * @notice 
 */

interface PaymentStructures {

  struct PaymentSchedule {
    uint256 totalAmount;
    uint256 amountSent;
    uint256 amountPerInterval;
    uint256 totalIntervals;
    uint256 intervalsProcessed;
    uint256 nextTransferOn;
    uint256 interval;
    address recipient;
    address sender;
    address token;
    bool alive;
  }

  enum Errors {
    Unauthorized,
    InsufficientApproval
  }

  event PaymentPlanStarted(
    address indexed sender,
    address indexed recipient,
    address token,
    uint256 totalAmount,
    uint256 interval
  );
  event IntervalStarted(
    uint256 indexed callableOn,
    uint256 indexed amount,
    address indexed token,
    uint256 planId,
    uint256 intervalNumber
  );
  event IntervalEnded(uint256 indexed planId, uint256 indexed intervalNumber);
  event PaymentPlanEnded(
    uint256 indexed planId,
    address indexed sender,
    uint256 totalAmount
  );
  event CallerFeeChanged(uint256 oldBips, uint256 newBips);
}

/**
 * @title RecurringPayments
 * @notice 
 * @notice 
 */
contract RecurringPayments is PaymentStructures, Ownable {
  uint256 planCounter;
  mapping(uint256 => PaymentSchedule) schedules;
  uint256 public callerFeeBips = 2; // Fee given to whoever initiates a payment
  uint256 public adminFeeBips; // Fee taken by admin

  uint256 constant maxAdminFeeBips = 10;
  uint256 constant maxCallerFeeBips = 40;

  uint256 constant public BIPS_DENOMINATOR = 10000;

  /** View Functions */

  function getPaymentDetails(uint256 id)
    external
    view
    returns (PaymentSchedule memory)
  {
    return schedules[id];
  }

  /** State Changing Internal Functions */

  function _endPaymentPlan(uint256 id) internal {
    PaymentSchedule memory plan = schedules[id];
    schedules[id].alive = false;
    emit PaymentPlanEnded(id, plan.sender, plan.amountSent);
  }

  function _startInterval(uint256 id) internal {
    PaymentSchedule memory plan = schedules[id];
    uint256 callableOn = schedules[id].interval + block.timestamp;
    uint256 intervalNumber = plan.intervalsProcessed + 1;
    schedules[id].nextTransferOn = callableOn;

    emit IntervalStarted(
      callableOn,
      plan.amountPerInterval,
      plan.token,
      id,
      intervalNumber
    );
  }

  function _fulfillInterval(uint256 id, address caller) internal {
    PaymentSchedule memory plan = schedules[id];
    IERC20 token = IERC20(plan.token);
    uint256 amountToTransfer = plan.amountPerInterval;
    address sender = plan.sender;
    address target = plan.recipient;
    uint256 interval = plan.intervalsProcessed + 1;
    require(plan.nextTransferOn <= block.timestamp, "Too early");
    require(plan.alive, "Plan has ended");

    // Check conditions here with an if clause instead of require, so that integrators dont have to keep track of balances
    if (
      token.balanceOf(sender) >= amountToTransfer &&
      token.allowance(sender, address(this)) >= amountToTransfer
    ) {
      uint256 callerFee = (amountToTransfer * callerFeeBips) / BIPS_DENOMINATOR;
      token.transferFrom(sender, target, amountToTransfer - callerFee);
      token.transferFrom(sender, caller, callerFee);
      schedules[id].amountSent += amountToTransfer;
      schedules[id].intervalsProcessed = interval;
      emit IntervalEnded(id, interval);
      if (interval < plan.totalIntervals) {
        _startInterval(id);
      } else {
        _endPaymentPlan(id);
      }
    }
  }

  /** State Changing External Functions */

  function cancelPaymentPlan(uint256 id) external {
    require(msg.sender == schedules[id].sender, "Unauthorized");
    _endPaymentPlan(id);
  }

  function createPaymentPlan(
    address target,
    address token,
    uint256 amountPerInterval,
    uint256 totalIntervals,
    uint256 intervalLength
  ) external {
    uint256 totalToTransfer = amountPerInterval * totalIntervals;
    require(
      IERC20(token).allowance(msg.sender, address(this)) >= totalToTransfer,
      "Insuff Approval"
    );
    uint256 id = ++planCounter;

    schedules[id] = PaymentSchedule({
      totalAmount: totalIntervals * amountPerInterval,
      amountSent: 0,
      amountPerInterval: amountPerInterval,
      totalIntervals: totalIntervals,
      intervalsProcessed: 0,
      nextTransferOn: 0,
      interval: intervalLength,
      recipient: target,
      sender: msg.sender,
      token: token,
      alive: true
    });
    _startInterval(id);
  }

  function runInterval(uint256 id) external {
    address caller = msg.sender;
    _fulfillInterval(id, caller);
  }

  function runIntervals(uint256[] memory ids) external {
    address caller = msg.sender;
    for (uint256 i = 0; i < ids.length; i++) {
      _fulfillInterval(ids[i], caller);
    }
  }

  function setCallerFee(uint256 bips) external onlyOwner {
    require(bips <= maxCallerFeeBips, "Too high of fee");
    uint256 oldFee = callerFeeBips;
    callerFeeBips = bips;
    emit CallerFeeChanged(oldFee, bips);
  }
}