# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# deps
install   :; forge install
update    :; forge update

# Build & test
build     :; forge build
coverage  :; FOUNDRY_PROFILE=coverage forge coverage
gas       :; forge snapshot --gas-report
gas-check :; forge snapshot --gas-report --check
test      :; forge test -vvv
clean     :; forge clean
fmt       :; forge fmt
