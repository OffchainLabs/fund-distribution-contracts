# Fund Distribution Contracts



## DAC-REWARDS

A smart contract that pushes the funds that accrued in it to a group of addresses.
You can use this contract to distribute ether evenly between the participants.
The participants are managed by an owner - but owner is only able to deny them from of future rewards (not rewards that have already accrued).
If a particular recipient is not able to recieve funds at their address, the payment will fallback to the owner.
This contract is expected to handle ether simply appearing in its balance (opposed to having an explicit `receive` function called).

The current system assumes the block gas limit will not decrease below 16m (but has a conservative margin is still kept to ensure transfers are always possible).

## Fee Routers

A set of smart contracts that pushes route funds (both native and erc20) across parent and child chains.

These are the supported routes:

1. ArbChildToParentRewardRouter.sol

    Route funds from an Arbitrum chain to its parent chain

2. OpChildToParentRewardRouter.sol

    Route funds from an OPStack chain to its parent chain

3. ParentToChildRewardRouter.sol

    Route funds from a parent chain to a child Arbitrum chain

When setting up a new route, make sure the token exists on both side by the configurated bridge or else fund can be stuck.

## Installation

1. Install [Foundry](https://github.com/foundry-rs/foundry):

```
curl -L https://foundry.paradigm.xyz | bash
```

2. Download dependency

```
make install
```

### Dependencies

```
make update
```

### Compilation

```
make build
```

### Testing

```
make test
```

### Code Coverage

```
make coverage
```

### Gas Report

```
make gas
```

### Gas Snapshot

```
make snapshot
```

### Compare with Gas Snapshot

```
make gas-check
```
