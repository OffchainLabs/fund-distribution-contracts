#!/bin/bash

export ORBIT_TEST="1"

cd lib/arbitrum-sdk && yarn gen:network && cd -

# if the above command fails, exit
if [ $? -ne 0 ]; then
    echo "Failed to generate network"
    exit 1
fi

yarn hardhat compile 

yarn mocha test/e2e/ --timeout 30000000 --bail
