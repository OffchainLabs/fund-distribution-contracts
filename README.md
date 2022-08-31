# DAC-REWARDS

A smart contract that pushes the funds that accrued in it to a group of addresses.
You can use this contract to distribute ether evenly between the participants.
The participants are managed by an owner - but owner is only able to deny them from of future rewards (not rewards that have already accrued).
If a particular recipient is not able to recieve funds at their address, the payment will fallback to the owner.
This contract is expected to handle ether simply appearing in its balance (opposed to having an explicit `receive` function called).

The current system assumes the block gas limit will not decrease below 16m (but has a conservative margin is still kept to ensure transfers are always possible).

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
