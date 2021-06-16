# Gorgeous token contract.

Source code for $GORGEOUS contract.

### Tests to pass:
- ✅ Tokenomics fees are correctly taken from each (qualifying) transaction.
- ✅ The redistribution tokenomics is correctly distributed among holders (which are not excluded from rewards)
- ✅ `swapAndLiquify` works correctly when the threshold balance is reached
- ✅ `maxTransactionAmount` works correctly and *unlimited* accounts are not subject to the limit
- ✅ `maxWalletBalance` works correctly and *unlimited* accounts are not subject to the limit
- ✅ Accounts excluded from fees are not subject to tx fees
- ✅ Accounts excluded from rewards do not share in rewards
- ✅ BNB collected/stuck in the contract can be withdrawn to liquidity by manager