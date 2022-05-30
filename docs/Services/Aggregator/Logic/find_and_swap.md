# Find and Swap
Finds the best route between fromToken and toToken and returns the path and amount out, then builds the transaction and caches it. Returns find's result, transaction raw data and proxy's inputs (swap struct.)

1. Checks if fromToken or toToken are network's value token (FTM in Fantom Network)
- if fromToken (**should_wrap**) == network's value token: calls **find_native_to_wrap** 
- if toToken (**should_unwrap**) == network's value token: calls **find_wrap_to_native** 
- else: calls **_init_find**
2. Builds transaction
3. Saves transaction in redis

```python
async def find_and_swap(request: PathRequest):

    chain, _from, _to = (request._chain, request.fromToken, request.toToken)
    swap_struct, res = None, None
    if should_wrap(chain, _from, _to):
        swap_struct, res = await find_native_to_wrap(
            request._chain,
            request._amount_in,
            request.deadline
        )
    elif should_unwrap(chain, _from, _to):
        swap_struct, res = await find_wrap_to_native(
            request._chain,
            request._amount_in,
            request.deadline
        )
    else:
        swap_struct, res = await _init_find(request)

    trx_result = build_transaction(request, swap_struct)
    save_transaction(
        request.chainId,
        request.walletAddress,
        request._from_token.symbol,
        request._to_token.symbol,
        request.amount_in,
        trx_result,
    )
    return res, trx_result, swap_struct
```
