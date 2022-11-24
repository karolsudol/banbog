# BANBOG

`Recurring payments contract`

## Usage

1.  - Approve the payment plan contract as the spender for the total amount to be sent. `token.approve(address(paymentPlanContract), totalAmount)`

2.  - Create a payment plan `createPaymentPlan(address target, address token, uint256 amountPerInterval, uint256 totalIntervals, uint256 intervalLength)`

      - `target` is the recipient of payments
      - `token` is the token to be used for payments
      - `amountPerInterval` is the total amount to be transfered per interval
      - `totalInverals` is the total number of intervals for the payment plan
      - `intervalLength` is the number of seconds between each payment

3.  - When a payment plan is started, an event is emitted to so that `vitalik` can process the payment.

4.  - When a new `interval` begins for a payment plan, an event is emitted specifying the exact unix timestamp when a payment can be facilitated. For off-chain integrators, all that is needed to initiate a payment is the plan id. Payment initiations can be batched together, as well. When an interval is fulfilled, an event is fired so that offchain integrators know to stop tracking it.

5.  - you can cancell `plan` by Revoking approval for the payment plan contract or `cancelPaymentPlan(uint256 id)`

## Scripts

1. `curl -L https://foundry.paradigm.xyz | bash`
2. `source ~/[.zshrc | .bashrc | .bash_profile | .zsh_profile]`
3. `foundryup`
4. `forge build`
5. `forge test`
