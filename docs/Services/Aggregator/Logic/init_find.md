# Init Find
In order to find the best possible route between two tokens, we try 3 different ways by calling **Path.best_path**:
1. Depth one: Searches for pairs containing both tokens in dgraph.
2. Depth two: Searches for pairs containing fromToken and base tokens, if found any, tries to find common pairs between base tokens and toToken.
3. Depth three: Searches for pairs containing fromToken and base tokens, if found any, tries to find common pairs between those pairs and other base tokens, then tries to find common pairs between those tokens and toToken. 
4. For each depth, after finding routes, calculates amount outs and returns the path with the higher amount out.
5. Compares amount out of depth one, depth two, and depth three and returns the path with the higher one.
6. Checks if the final amount out is higher than the minimum amount and raises NotExpectableAmountOut error.
7. Checks the slippage rate.
8. Depends on the depth of output path, calls **find_one**, **find_two** or **find_three** and returns proxy's inputs (swap struct) and find response.

```python
async def _init_find(request: PathRequest) -> Tuple[SwapStruct, dict]:

    res = await Path(
        request.chainId, request._from_token, request._to_token, request._amount_in
    ).best_path()

    amounts_in_1, amount_out_1, pairs_1 = res[0]
    amounts_in_2, amount_out_2, paths_2 = res[1]
    amounts_in_3, amount_out_3, paths_3, first_step, second_step = res[2]

    amount_outs = []
    if amount_out_1:
        amount_outs.append(amount_out_1)

    if amount_out_2:
        amount_outs.append(amount_out_2)

    if amount_out_3:
        amount_outs.append(amount_out_3)

    if amount_outs:
        amount_out = max(amount_outs[:])
        flags = make_flags(request=request)
    else:
        raise Errors.NoPathFound()

    if amount_out + cc.AMOUNT_OUT_THRESHOLD < cc.AMOUNT_OUT_MINIMUM:
        raise Errors.NotExpectableAmountOut(
            request=request, amount_out=amount_out)
        
    if int(amount_out - (amount_out * request.slippage * 0.01)) < 0:
        raise Errors.LowSlippageRate
        (request=request)

    if amount_out == amount_out_1:
        res, swap_struct = await find_d1(
            request, amounts_in_1, amount_out, pairs_1, flags
        )

    if amount_out == amount_out_2:
        res, swap_struct = await find_d2(request, amount_out, paths_2, flags)

    if amount_out == amount_out_3:
        res, swap_struct = await find_d3(
            request, amount_out, paths_3, first_step, second_step, flags
        )
    return swap_struct, res
```