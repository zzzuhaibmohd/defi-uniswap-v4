# Test setup

```shell
# Fill out environment variables inside .env
cp .env.sample .env

# Build exercises
forge build --via-ir

# Build solutions
FOUNDRY_PROFILE=solution forge build --via-ir

# Get block number
FORK_URL=...
FORK_BLOCK_NUM=$(cast block-number --rpc-url $FORK_URL)

# Test exercise
forge test --fork-url $FORK_URL --fork-block-number $FORK_BLOCK_NUM --match-path test/Router.test.sol -vvv

# Test solution
FOUNDRY_PROFILE=solution forge test --fork-url $FORK_URL --fork-block-number $FORK_BLOCK_NUM --match-path test/Router.test.sol -vvv

# Try building from scratch if you're having trouble
forge clean
```
