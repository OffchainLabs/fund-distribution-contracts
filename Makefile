# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# deps
install   :; forge install
update    :; forge update

# Build & test
build     :; FOUNDRY_PROFILE=optimized forge build
coverage  :; forge coverage
gas       :; FOUNDRY_PROFILE=optimized forge test --gas-report
gas-check :; FOUNDRY_PROFILE=optimized forge snapshot --check
snapshot  :; FOUNDRY_PROFILE=optimized forge snapshot
test-forge:; forge test -vvv
clean     :; forge clean
fmt       :; forge fmt
test      :  test-forge
