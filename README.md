# Blockchain Eng Template Repo
## Current Setup
### Overview
- Hardhat + Ethers v6 + Foundry
- Solidity compiler config is synced between hardhat and foundry, with `foundry.toml` being the source
- Arbitrum SDK formatting config for `ts`, `js`, `json` files
- Forge formatter for `sol` files.
- `yarn minimal-publish` script to generate a minimal `package.json` and `hardhat.config.js` before publishing to npm
- CI
    - Audit
    - Lint
    - Unit tests
    - Fork tests
    - Contract size
    - Foundry gas snapshot
    - Check signatures and storage
    - E2E testing with Hardhat + Arbitrum SDK + testnode

## Removing Sample Files
Run `scripts/template/delete-samples.bash` to remove `Counter.sol` and sample test files.

## Compiler Settings
Solc version and optimizer runs are defined in `foundry.toml` and copied by `hardhat.config.ts`.

## Fork Tests
Fork tests are located in `test/fork/`.
Use `$<CHAIN_NAME>_FORK_URL=*** $<CHAIN_NAME>_FORK_URL=*** yarn test:fork`.

`yarn test:fork` will pass if there are no test files.

### Disabling / Removing
To disable the end to end testing CI jobs, remove `on: pull_request:` from `.github/workflows/test-fork.yml`

To completely remove fork test setup:
- Remove `.github/workflows/test-fork.yml`
- Remove the `test:fork` script from `package.json`
- Remove `test/fork`

### Adding to Existing Projects
To add the fork test setup to an existing hardhat+foundry project:
- Copy `.github/workflows/test-fork.yml`
    - `run: yarn minimal-install` may need to be changed to `run: yarn`
- Set GitHub secrets for RPC url's
- Copy `test/fork/` directory
- Copy `test:fork` package script

## E2E Tests and the Arbitrum SDK
End to end tests are located in `test/e2e/`, and ran by `yarn test:e2e`.

The GitHub workflow defined in `.github/workflows/test-e2e.yml` will run test files against an L1+L2 nitro testnode setup by default. There are commented out jobs that add an L3 with ETH or custom fees.

It is recommended to use `testSetup` defined in `test/e2e/testSetup.ts` to get signers, providers, and network information. Note that there is also a `testSetup` function defined in the SDK, don't use that one.

This repository uses ethers v6, but the Arbitrum SDK uses ethers v5. 
A separate ethers v5 dev dependency is included and can be imported for use with the SDK.
```typescript
import { ethers as ethersv5 } from 'ethers-v5'
```

### Disabling / Removing
To disable the end to end testing CI jobs, remove `on: pull_request:` from `.github/workflows/test-e2e.yml`

To completely remove end to end test setup:
- `forge remove lib/arbitrum-sdk && rm .github/workflows/test-e2e.yml && rm -rf test/e2e`
- Remove `test:e2e` package script and modify `prepare` package script
- Remove `.mocharc.json`

### Adding to Existing Projects
To add the end to end setup to an existing hardhat+foundry project:
- `forge install https://github.com/OffchainLabs/arbitrum-sdk@<version>`
- Copy `.github/workflows/test-e2e.yml`
- Copy `test/e2e/` directory
- Copy `test:e2e` and `prepare` package scripts 
- Copy `.mocharc.json`

## Signatures and Storage Tests
These will fail if signatures or storage of any contract defined in `contracts/` changes.

Abstract contracts and interfaces are not checked. `scripts/template/print-contracts.bash` produces the list of contracts that are checked in these tests.

Use `yarn test:signatures` and `yarn test:storage`.

### Disabling / Removing
To disable the CI jobs, remove or comment out `test-storage` and `test-sigs` jobs in `.github/workflows/test.yml`

To completely remove:
- `rm -rf test/storage/ test/signatures/`
- Remove `test:storage` and `test:signatures` package scripts
- Remove `test-storage` and `test-sigs` jobs from `.github/workflows/test.yml`

### Adding to Existing Projects
To add to an existing hardhat+foundry project:
- Copy `test/storage/` and `test/signatures/` directories
- Copy `test:storage` and `test:signatures` package scripts
- Copy `test-storage` and `test-sigs` jobs from `.github/workflows/test.yml`

## Publishing to NPM
A helper script, `minimal-publish` is included to generate a minimal `package.json` and `hardhat.config.js` before publishing to NPM.

`yarn minimal-publish` will:
- Generate a minimal `package.json` and `hardhat.config.js` from the existing `package.json` and solidity compiler settings
- Prompt the user to confirm these files
- Publish to NPM if the user confirms
- Restore original files
- Commit and tag if published successfully

Note that `yarn publish --non-interactive` is used, so there will be no prompt for package version. See `scripts/template/publish.bash`

## TODO / Wishlist
- license?
- nice libraries that leverage foundry’s fork cheatcodes to mock general cross chain interactions (probably done best as a separate project)
- mutation testing
- slither / other static analysis
- https://github.com/OffchainLabs/nitro-contracts/pull/128/files
- general proxy upgrade safety
- ...
