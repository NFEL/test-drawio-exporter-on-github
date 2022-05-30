# Middleware
In order to check if request ‌has the proper elements it has to pass to through the middleware.
## Populate chain Middleware
1. Wallet Address

Checks if request.walletAddress exist and is type of Address.
```python
def check_wallet_address(request: PathRequest):
    if request.walletAddress is not None:
        try:
            request.walletAddress = Address(
                request.walletAddress)
        except ValueError:
            raise Errors.WalletConnection(request=request)
```

2. Chain

Checks if request.chain_id is in supported chains and if yes,creates request._chain(Chain object).
```python
def check_and_make_chain(chain_id: ChainId):
    if chain_id not in Network._SUPPORTED_CHAINES():
        raise Errors.ChainIdNotSupported
    chain = Chain(**{"chain_id": chain_id})
    return chain
```

3. Checks if request.fromToken and request.toToken are network_value_token(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE") or not.

```python
    network = Network(chain_id)
    if token_address == network.network_value_address:
        return network.network_value_wrapped_address
    return token_address
```

4. Token object

Tries to find token in redis using it's identifier(address), if it couldn't find token, tries to find it in dgraph, then makes the Token object.
raises Errors.TokenNotFound if couldn't find token
```python
async def make_token_obj(
        token_address: Address,
        chain_id: ChainId
) -> Token:

    token = Token.get_cache(
        key=token_address,
        chain_id=chain_id
    )
    if token is not None:
        return token
    token = await dgraph_client().find_by_predicate(
        ("address", token_address),
        [
            "uid",
            "expand(_all_)"

        ])
    if len(token) >= 1:
        token = token[0]
        logging.warning(
            f"Token {token_address} doesn't exist in redis db at make_token_obj.")
        return make_token(token, chain_id)

    raise Errors.TokenNotFound()
```

5. Amount

Creates request._amount_in and request.amount_out by multiplying amount and 10 ** token.decimal. raises Errors.LowAmountIn if couldn't find any amount.
```python
def check_amounts(request: PathRequest):
    if request.amount_in:
        request._amount_in = int(request.amount_in * 10 **
                                 request._from_token.decimal)
    if request.amount_out:
        request._amount_out = int(request.amount_out * 10 **
                                  request._to_token.decimal)

    if not request._amount_in and not request._amount_out:
        raise Errors.LowAmountIn(request=request)
    return request
```

6. Value

Checks if request.fromToken is network_value_address. If yes, changes request.

```python
def network_value_middleware(request: PathRequest) -> PathRequest:
    network = Network(request.chainId)
    if request.fromToken == network.network_value_address:
        request.value = request._amount_in
    return request
```

7. Burn rate

Checks if from_token or to_token has burn_rate
```python
def set_burn_rate_flag(request: PathRequest) -> bool:
    if request._burning_detail:
        if request._burning_detail.from_token_burn_rate not in (None, 0) or\
                request._burning_detail.to_token_burn_rate not in (None, 0):
            return True

    if request._from_token.burn_rate not in (None, 0) or\
            request._to_token.burn_rate not in (None, 0):
        return True

    if request._has_burn_rate:
        return True
    return False
```

8. Balance

Checks if user has enough balance in their wallet.
```python
async def check_balance(request: PathRequest) -> PathRequest
    chain = request._chain
    try:
        _token_in, _native_token = (
            chain
            .batch_reader_contract
            .functions
            .multiGetInfo(
                [request._from_token.address],
                chain.proxy_address,
                request.walletAddress
            ).call()
        )
        has_balance = ((_token_in[1] >= request._amount_in)
                       and (_native_token[1] >= 0.2 * 10 ** 18))
    except Exception as e:
        logging.error(f"at check balance middleware: {e}")
        print(f"at check balance middleware: {e}")

        return
    return has_balance
```

