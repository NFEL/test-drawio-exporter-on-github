# Insert and Update Token Prices
Calculate price of tokens comparing to network's value token.
1. Get network's base token

We choose the network's wrapped token (wrapped of network's value) as the base token and we compare other tokens to this token.

```python
async def _get_chain_base_token(chain_id: ChainId):
    try:
        chain_token_address = Chain(
            **{"chain_id": chain_id}).network_wrapped_token_address

        chain_token_uid = Token.get_uid(chain_id, chain_token_address)
        if not chain_token_uid:
            logging.critical(
                "There is no uid for network value wrapped token! at updating_token_prices.")
            return None
        dgraph_token = await dgraph_client().find_by_uid(
            chain_token_uid,
            ["address"]
        )
        if not dgraph_token:
            logging.critical(
                f"Network wrapped token: {chain_token_uid} doesn't have an address in dgraph!")
            return None, None
        return chain_token_address, chain_token_uid
    except Exception as e:
        logging.error(f"Exception {e} occurred at _get_chain_base_token.")
        return None, None
```

2. Insert base token's price (price = 1) to database.

```python
async def insert_base_token_price(
    chain_id: ChainId,
    chain_token_address: Address
):
    """ This function takes chain_token_uid and inserts price = 1 for it's object"""
    try:
        token = Token.get_cache(
            key=chain_token_address,
            chain_id=chain_id)

        token.price = 1
        token.cache()

        chain_token_price_mutation = token.save_token()
        await dgraph_client().insert(chain_token_price_mutation)
    except Exception as e:
        logging.error(f"Exception {e} occurred at insert_base_token_price.")
```

3. Get pairs of base token

```python
async def get_base_token_pairs(
    base_token_uid: Uid
) -> List[Node]:
    """ this function takes base_token_uid and returns all pairs connected to chain token """
    try:
        res = await dgraph_client().find_by_uid(
            base_token_uid,
            [
               "pairs {uid expand(_all_)}"

            ]
        )
        return res.get("pairs")
    except Exception as e:
        logging.error(f"Exception {e} occurred at get_base_token_pairs.")
        return None
```

4. Make Pair object of base token's pairs
5. Calculate price of each pair's tokens, based on pair's protocol.

```python
    _protocol = _pair.protocol
    if _protocol in (
        PairProtocol.UNISWAP.value,
        PairProtocol.SOULSWAP.value,
        PairProtocol.SOLIDLY.value
    ):
        try:
            other_token_index = 1 - chain_token_index
            price, token_reserve = calculate_amm_price(
                other_token_index,
                chain_token_index,
                _pair
            )
```

```python
else:
    for address, index in tokens_indexes.items():
        if index == chain_token_index:
            continue
        reserves, price = caculate_not_amm_price(
            index, chain_token_index, _pair)
```

6. calculate AMM prices

- Takes:
  1. base token's index in pair
  2. toToken's index in pair
  3. the object of Pair
- Returns:
  1. price of toToken
  2. pair's reserves
- Divides reserve of base token to reserve of toToken

```python
def calculate_amm_price(
    token_index: int,
    chain_token_index: int,
    pair: Pair
):
    """ this function calculates prices of amm pairs by deviding their reserves to each other """
    try:
        _res = (pair.reserves[chain_token_index] / (10 ** pair.decimals[chain_token_index])) / \
            (pair.reserves[token_index] / (10 ** pair.decimals[token_index]))
    except Exception as e:
        logging.error(f"Exception {e} occurred at calculate_amm_price.")
        return None, None
    return _res, pair.reserves[token_index]
```

7. Calculate Not-AMM prices

- Takes:
  1. base token's index in pair
  2. toToken's index in pair
  3. the object of Pair
- Returns:
  1. price of toToken
  2. pair's reserves
- For 1 as amount_in, base token as fromToken and other token as toToken, calls the amount_out method of each Pair class.

```python
def calculate_not_amm_price(token_index: int, chain_token_index: int, pair: Pair):
    try:
        amount_in: WithDecimal = int(
            0.01 * 10 ** pair.decimals[token_index])

        price: WithDecimal = pair.amount_out(
            token_index,
            chain_token_index,
            amount_in
            )

        if price == 0:
            return None, None
        price: NoDecimal = price / \
            (10 ** pair.decimals[chain_token_index])
        price *= 100
        logging.info(
            f"NOT amm: {price} {pair.token_symbols} {pair.protocol} ")
        return pair.reserves[token_index], price
    except Exception as e:
        logging.error(f"Exception {e} occurred at calculate_not_amm_price.")
        return None, None
```

8. Calculate the average price

Lots of tokens have more than one common pairs with base token, we set the average price as the final price.

```python
async def update_price_predicate(uid_price_map: Dict[Uid, Tuple[int, float]], chain_id: ChainId):
    """ gets all of tokens prices and calculates a weighted average
     to set price predicate on it's node and in redis """
    for uid, value in uid_price_map.items():
        try:
            numerator, denominator = [
                res*price for res, price in value], [res for res, price in value]
            final_price = sum(numerator) / sum(denominator)

            token_address = Token.get_identifier(
                chain_id,
                uid
            )
            token = Token.get_cache(token_address, chain_id)
            token.price = final_price
            token.cache()
            await dgraph_client().insert(token.save_token())
            logging.info("*************UPDATING PRICE************")

        except Exception as e:
            logging.error(
                f' {datetime.now():%H:%M:%S} - {e} at update_price_predicate.')
```

9. Update price of remaining tokens.

- **Get remaining tokens**

  Some tokens don't have any common pair with base token, so we need to find another solution to calculate their prices.

  First we query dgraph and find tokens with no prices

```python
    async def get_remaining_tokens(chain_id: int, updated_token_uids: Set[Uid]) -> Set[Uid]:
        try:
            _tokens = await dgraph_client().find_by_chain_id(chain_id=chain_id, schema_type="Token")
            tokens = {_.get("uid") for _ in _tokens.get("~chain")}
            return tokens - updated_token_uids
        except Exception as e:
            logging.error(f"Exception {e} occurred at get_remaining_tokens.")
            return None
```

- **Get base tokens**

Then we find base tokens (first 15 tokens that have most pairs). we try to get their uid from redis and if couldn't find them there, we query dgraph.

```python
async def find_base_tokens(chain_id: ChainId):
    tokens = await dgraph_client().find_base_tokens()
    base_tokens = []
    for token in tokens:
        if token.get("address") is None:
            logging.critical(
                f"token {token.get('uid')} doesn't have address in dgraph.")
            continue
        if token.get("chain").get("chain_id") == chain_id:
            base_tokens.append(token.get("uid"))

    save_base_tokens(chain_id, base_tokens)
    return base_tokens
```

- **Find common pairs between remaining tokens and base tokens**

In order to calculate prices, we need to find some pairs that have both remaining token and base token as tokens.

After finding the first pair containing both remaining token and base token, we calculate the price and insert it to both redis and dgraph.

```python
    for token_uid in remaining_tokens:
        price = None
        token_address = Token.get_identifier(
            chain_id=chain_id, uid=token_uid)
        for _bt_uid in base_tokens:
            pairs = await dgraph_client().common_pairs(from_token=token_uid, to_token=_bt_uid)
            if pairs is None:
                continue
            pairs = {_.get("uid") for _ in pairs.get("pairs")}
            token = Token.get_cache(token_address, chain_id)
            price = await _calculate_price(chain_id=chain_id, pairs=pairs, base_token_uid=_bt_uid, token_address=token_address)
            if price is None:
                continue
            token.price = price
            token.cache()
            await dgraph_client().insert(token.save_token())
            break
```

- **Calculate remaining price**

For obtained pair as the common pair of remaining token and base token, we calculate price of remaining based on Pair object's protocol (AMM/Not-Amm). Then we call _final_price function which calculates the average price.
```python
async def _calculate_price(chain_id: int, pairs: Set[Uid], base_token_uid: Uid, token_address: Address):
    _base_token_address = Token.get_identifier(
        chain_id=chain_id, uid=base_token_uid)

    numerator, dominator = 0, 0
    for _pair_uid in pairs:
        _reserves, _price = None, None
        _pair = await dgraph_client().find_by_uid(uid=_pair_uid, predicates=["expand(_all_)"])

        _pair = await make_pair_obj(pair=_pair, chain_id=chain_id)
        _protocol = _pair.protocol
        if _protocol == PairProtocol.UNISWAP.value or\
                _protocol == PairProtocol.SOULSWAP.value or\
                _protocol == PairProtocol.SOLIDLY.value:

            _reserves, _price = await _calculate_amm_price(pair=_pair, base_token_address=_base_token_address)
        else:
            _reserves, _price = await _calculate_non_amm_price(pair=_pair, base_token_address=_base_token_address, token_address=token_address)
        if _reserves is None or _price is None:
            continue
        numerator += _reserves * _price
        dominator += _reserves
    return await _final_price(numerator=numerator, dominator=dominator, base_token_address=_base_token_address, chain_id=chain_id)
```
```python
async def _final_price(numerator, dominator, base_token_address: Address, chain_id: int):
    try:
        _price = numerator / dominator
        token = Token.get_cache(key=base_token_address,
                                chain_id=chain_id)
        return _price * token.price
    except Exception as e:
        logging.error(f"{e} happened at _final_prices")
        return None
```

