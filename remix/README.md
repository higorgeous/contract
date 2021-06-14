### Tests to pass:
- Tokenomics fees can be added/removed/edited
- Tokenomics fees are correctly taken from each (qualifying) transaction
- The redistribution tokenomics is correctly distributed among holders (which are not excluded from rewards)
- `swapAndLiquify` works correctly when the threshold balance is reached
- `maxTransactionAmount` works correctly and *unlimited* accounts are not subject to the limit
- `maxWalletBalance` works correctly and *unlimited* accounts are not subject to the limit
- Accounts excluded from fees are not subjecto tx fees
- Accounts excluded from rewards do not share in rewards
- BNB collected/stuck in the contract can be withdrawn (see)
