# Filter Pairs
## Delete low reserve pairs
Some pairs have low reserves therefor they have no use for swaps.
1. Queries dgraph and gets all pairs (uid, reserves, decimals, tokens {uid}).
```python
async def get_all_pairs(chain_id: ChainId):
    try:
        all_pairs = await dgraph_client().find_by_chain_id(
            chain_id,
            "Pair",
            [
                "uid",
                "reserves",
                "decimals",
                "tokens { uid }"
            ]
        )
        return all_pairs.get("~chain")
    except Exception as e:
        logging.error(f"Expection {e} occured during get_all_pairs.")
        return None
```

2. Checks if pairs don't have any of needed predicates and if found any, deletes it.
```python
async def delete_pair_with_no_predicate(pair: Dict):
    if None in (pair.get("reserves"), pair.get("decimals"), pair.get("tokens")):
        logging.critical(f"pair {pair.get('uid')} doesn't have reserve.")
        await dgraph_client().delete(pair.get("uid"))
        return False
    return True
```

3. For all of pairs, divides pair's reserves into the 10 ** pair's decimals.
4. Creates a list of dictionaries containing each pair's uid, reserves (reserve / 10 ** decimal) and tokens (uid of tokens that are connected to pair). 
```python
async def split_things(chain_id: ChainId):
    pairs = await get_all_pairs(chain_id)
    if not pairs:
        logging.error("No pair exist at split_things.")
    made_pairs = []
    for pair in pairs:
        if await delete_pair_with_no_predicate(pair):
            token_uids = []
            decimals = [int(decimal)
                        for decimal in pair.get("decimals").split("#")]
            pair_reserves = [(int(reserve)/10**decimals[i])
                             for i, reserve in enumerate(pair.get("reserves").split("#"))]

            for token in pair.get("tokens"):
                token_uids.append(token.get("uid"))

            made_pairs.append({
                "uid":  pair.get("uid"),
                "reserves": pair_reserves,
                "tokens": token_uids
            })

    return made_pairs
```

5. For all of pairs (list of dictionaries), checks if pair's reserve is less than 5 and if yes, deletes it.
```python
async def delete_low_reserve_pairs(pair: Dict):
    low_reserve = False
       for reserve in pair.get("reserves"):
            if reserve < 5:
                low_reserve = True
        if low_reserve:
            await dgraph_client().delete(pair.get("uid"))
            logging.info(
                f"deleted pair {pair.get('uid')} for having low reserves at delete_low_reserve_pairs.")
            return True
```

6. For all of that pair's tokens, queries dgraph and finds the uid of pairs which are connected to that token.
7. Removes the connection between token and all of it's pairs.
8. Connect token to all of it's pairs except that one pair with low reserves.
```python
async def filter_pairs_of_tokens(token_uid: Uid, pair_uid:Uid):
    token_pairs = await dgraph_client().find_by_uid(
        token_uid,
        [
            "pairs { uid }"
        ]
    )
    if token_pairs is None:
        logging.warning(
            f"Found a pair {pair_uid} with on tokens at filter_pairs_of_tokens.")
    else:
        _pairs = []
        for token_pair in token_pairs.get("pairs"):
            if token_pair.get("uid") != pair_uid:
                _pairs.append({"uid": token_pair.get(
                    "uid"), "dgraph.type": dt.PAIR})

        await dgraph_client().delete(token_uid, ["pairs"])
        logging.info(
            f"deleted all of token {token_uid} pairs at filter_pairs_of_tokens.")
        await dgraph_client().insert({
            "uid": token_uid,
            "pairs": _pairs,
            "dgraph.type": dt.TOKEN
        })
        logging.info(
            f"inserted pairs of token {token_uid} to dgraph at filter_pairs_of_tokens.")
```
9. Check out the whole thing.
```python
async def filter_pairs(chain_id: ChainId):
    pairs = await split_things(chain_id)
    if len(pairs) < 1:
        return None
    for pair in pairs:
        if await delete_low_reserve_pairs(pair):
            if pair.get("tokens") is not None:
                for token in pair.get("tokens"):
                    await filter_pairs_of_tokens(token, pair.get("uid"))
    logging.info(
        "All of pairs with low reserves are gone.")
```

## Delete pairs with no token
After setting price predicate to tokens, some tokens might end up with no price (because of not having any common pairs with base tokens), therefore they have no use for us and we cannot calculate output amount for them, so we delete them. after deleting these tokens we need to check all pairs and delete those with no tokens.
1. Queries dgraph and get tokens of all pairs
```python
pairs = await dgraph_client().find_by_chain_id(
        chain_id,
        "Pair",
        [
            "uid",
            "tokens { uid }"
        ]

    )
    pairs = pairs.get("~chain")
```
2. Checks if pairs have tokens 
```python
for pair in pairs:
        if pair is None:
            return None
        if pair.get("tokens") is None:
            await dgraph_client().delete(pair.get("uid"))
```