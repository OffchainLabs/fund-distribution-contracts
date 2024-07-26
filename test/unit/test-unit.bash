#!/bin/bash

# early exit on failure
set -e

# run hardhat tests if there are any
test $(find test/unit -name '*.test.ts' | wc -l) -eq 0 || yarn hardhat test $(find test/unit -name '*.test.ts')

# run foundry tests if there are any
test $(find test/unit -name '*.t.sol' | wc -l) -eq 0 || forge test --match-path 'test/unit/**/*.t.sol'