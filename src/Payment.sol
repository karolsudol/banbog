// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';


/**
 * @title The Payment contract
 * @notice A Payment contract provides a subcription service between a merchant and a consumer
 * @notice A merchant creates a plan by calling the payment contract 
 */
contract Payment {
  uint public nextPlanId; // unique id for each plan
  
  // 
  struct Plan {
    address merchant;
    address token;
    uint amount;
    uint frequency;
  }

  /**
 * @title Subscription
 * @param subscriber - address of the customer wallet address
 * @param start a date of the first payment
 * @param nextPayment is recalulated every time payment is received
 * @notice
 */
  struct Subscription {
    address subscriber;
    uint start; 
    uint nextPayment;
  }
  mapping(uint => Plan) public plans; // hold subcription plan indexed by plan id
  mapping(address => mapping(uint => Subscription)) public subscriptions; // indexed by customer - subscriber adress and then by plan ids


  /**
 * @notice events
 */
  event PlanCreated(
    address merchant,
    uint planId,
    uint date
  );
  event SubscriptionCreated(
    address subscriber,
    uint planId,
    uint date
  );
  event SubscriptionCancelled(
    address subscriber,
    uint planId,
    uint date
  );
  event PaymentSent(
    address from,
    address to,
    uint amount,
    uint planId,
    uint date
  );


  /**
 * @notice merchant creates plan by specifing
 * @param token of the payment
 * @param amount of each payment
 * @param frequency of the payments as TS in seconds
 */
  function createPlan(address token, uint amount, uint frequency) external {
    require(token != address(0), 'address cannot be null address');
    require(amount > 0, 'amount needs to be > 0');
    require(frequency > 0, 'frequency needs to be > 0');
    plans[nextPlanId] = Plan(
      msg.sender, 
      token,
      amount, 
      frequency
    );
    nextPlanId++; // plan is not overitten but stored in a plan id mapping
  }


  /**
 * @notice customer selects a plan  by selecting
 * @param planId of the existing plan by pointing to its id
 */
  function subscribe(uint planId) external {
    IERC20 token = IERC20(plans[planId].token);
    Plan storage plan = plans[planId];
    require(plan.merchant != address(0), 'this plan does not exist');

    token.transferFrom(msg.sender, plan.merchant, plan.amount);  // first payment of the subscription
    emit PaymentSent(
      msg.sender, 
      plan.merchant, 
      plan.amount, 
      planId, 
      block.timestamp
    );

    subscriptions[msg.sender][planId] = Subscription(
      msg.sender, 
      block.timestamp, 
      block.timestamp + plan.frequency
    );
    emit SubscriptionCreated(msg.sender, planId, block.timestamp);
  }

  /**
 * @notice customer selects a plan  by selecting
 * @param planId of the existing plan by pointing to its id
 */
  function cancel(uint planId) external {
    Subscription storage subscription = subscriptions[msg.sender][planId];
    require(
      subscription.subscriber != address(0), 
      'this subscription does not exist'
    );
    delete subscriptions[msg.sender][planId]; // remove subscription mapping 
    emit SubscriptionCancelled(msg.sender, planId, block.timestamp);
  }


  /**
 * @notice anyone can call the pay method, call this func to repay missed payment -> catch up -> subcription as normal
 * @param planId of the existing plan by pointing to its id
 */
  function pay(address subscriber, uint planId) external {
    Subscription storage subscription = subscriptions[subscriber][planId];
    Plan storage plan = plans[planId];
    IERC20 token = IERC20(plan.token);
    require(
      subscription.subscriber != address(0), 
      'this subscription does not exist'
    );
    require(
      block.timestamp > subscription.nextPayment,
      'not due yet'
    );

    token.transferFrom(subscriber, plan.merchant, plan.amount);  
    emit PaymentSent(
      subscriber,
      plan.merchant, 
      plan.amount, 
      planId, 
      block.timestamp
    );
    subscription.nextPayment = subscription.nextPayment + plan.frequency; // recalculate the date of next payment
  }
}
