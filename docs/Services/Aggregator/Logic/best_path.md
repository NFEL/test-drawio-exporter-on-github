# Best Path

This module's purpose is to find the best pair with the highest output amount and calculates amount out for it.

## Find pair and amount out
Finds the best pair for tokenA -> tokenB and calculates amount out for it.
```python
async def find_pair_and_amount_out(
    chain_id: ChainId,
    token_in: Token,
    token_out: Token,
    amount_in: WithDecimal,
):
    pair = await find_and_cache_the_right_pair(
        chain_id,
        token_in,
        token_out,
        amount_in
    )
    if not pair:
        return None, None
    amount_out = calculate_amount_out_for_pair(
        pair_obj=pair,
        token_in=token_in,
        token_out=token_out,
        amount_in=amount_in
    )
    return amount_out, pair
```

## Find and cache the best pair
1. Using tokenA and amount in, calculates the number of edge (pn).
```python
def calculate_number_of_edge(
    token_in: Token,
    amount_in: WithDecimal
):
    try:
        amount_in = convert_to_ftm(amount_in, token_in)
        amount_in: NoDecimal = amount_in / 10 ** token_in.decimal
        power = round(math.log(amount_in, 2))
        power = max(power, 0)
        edge = f"p{power}"
        return edge
    except Exception as e:
        logging.error(f"Exception {e} occurred at calculate_number_of_edge.")
```
2. Finds and caches the best pair.

Finding pair is implemented in 3 different ways:

    1. Redis
    2. Facets
    3. Common pairs

### Find the best pair from redis

After finding the best pair for exchanging tokenA -> tokenB for a specified amount, we cache the pair uid in redis (with a deadline), so while finding the best pair, first thing to do is to check redis and search for it.

1. Gets pair's uid from redis.
2. Makes the Pair object.
3. Syncs pair.
4. Returns the updated pair.

In each function, after finding the best pair, we cache it's uid in redis.

```python
async def get_the_best_pair_from_redis(
    chain_id: ChainId,
    token_in: Token,
    token_out: Token,
    edge: str

):
    try:
        pair_uid = get_chosen_pair(
            chain_id, token_in.uid, token_out.uid, edge)

        if pair_uid not in (None, "0"):
            logging.debug(
                "Couldn't find the best pair in redis at get_the_best_pair_from_redis.")

            pair_obj = await dgraph_client().find_by_uid(
                pair_uid,
                [
                    "uid",
                    "expand(_all_)"
                ]
            )

            pair_obj = await make_pair_obj(pair_obj, chain_id)
            pair_obj = await sync_pairs(chain_id, [pair_obj])
            return pair_obj[0]
    except Exception as e:
        logging.error(
            f"Exception {e} occurred at get_the_best_pair_from_redis.")
        return None
```

### Find the best pair by facets

While updating pairs, we check the "hash" predicate of them and compare it to old hashes. If there was a difference between the old hash and the new hash (it means pairs' reserves have been changed), we save their uid as "changed pairs" in redis and we set **facets** on them.

In order to find the best pair to exchange tokenA -> tokenB, if we couldn't find the pair in redis, we query dgraph and check facets, and choose the pair with the highest one.

1. Queries dgraph and finds the pair with highest facets .
2. Makes the Pair object.
3. Syncs pair.
4. Returns the updated pair.

```python
async def get_the_best_pair_by_facets(
        chain_id: ChainId,
        token_in: Token,
        token_out: Token,
        edge
):
    try:
        token_in_uid = token_in.uid
        token_out_uid = token_out.uid

        response = await dgraph_client().depth_one_best_path(

            uid0=token_in_uid,
            uid1=token_out_uid,
            relation=edge,
            pair_predicates=["uid", "expand(_all_)"],
        )
        if not response:
            logging.debug(
                f"There are no facests between token_in: {token_in_uid} and token_out: {token_out_uid} at get_the_best_pair_by_facets.")
            return None

        pair = response[0].get(edge)[0]
        pair_obj = await make_pair_obj(pair, chain_id)
        pair_obj = await sync_pairs(chain_id, [pair_obj])
        return pair_obj[0]

```

**Dgraph query**


```graphql
{query(func: uid(uid0)){
                    {edge} @facets(orderdesc: uid1) {
                        uid
                    }
                }
                }
```

### Find the best pair by common pairs
1. Finds common pairs between tokenA and tokenB.
2. Sync all of found pairs.
3. Calculates amount out for all of updated pairs.
4. Returns the pairs with the highest amount out.
```python
async def get_the_best_pair_by_common_pairs(
    chain_id: ChainId,
    token_in: Token,
    token_out: Token,
    amount_in: WithDecimal
):
    try:
        pair_uids = await dgraph_client().common_pairs(token_in.uid, token_out.uid)
        if pair_uids is None:
            logging.debug(
                f"There are no common pairs between token_in: {token_in.uid} and token_out: {token_out.uid} at get_the_best_pair_by_common_pairs.")
            return None

        pair_uids = pair_uids.get("pairs")
        uids = [uid.get("uid") for uid in pair_uids]
        updated_pairs = await sync_pairs(chain_id, uids)

        logging.debug(
            f"Synced {len(updated_pairs)} pairs at get_the_best_pair_by_common_pairs.")
        pairs = []
        for pair in updated_pairs:
            amount_out = calculate_amount_out_for_pair(
                pair_obj=pair, token_in=token_in, token_out=token_out, amount_in=amount_in)
            if amount_out is None:
                continue
            pairs.append({
                "amount_out": amount_out,
                "pair": pair
            })
        if len(pairs) > 0:
            pairs = sorted(pairs, key=lambda d: d['amount_out'])
            return pairs[0].get("pair")
    except Exception as e:
        logging.error(
            f"Exception {e} occurred at get_the_best_pair_by_common_pairs.")
        return None
```

3. Calculates the amount out for pair.

Calls Pair's amount_out method.
```python
def calculate_amount_out_for_pair(
    token_in: Token,
    token_out: Token,
    amount_in: WithDecimal,
    pair_obj: Pair
):
    try:
        for i, token in enumerate(pair_obj.token_addresses):
            if token == token_in.address:
                index1 = i

        for i, token in enumerate(pair_obj.token_addresses):
            if token == token_in.address:
                index1 = i

            if token == token_out.address:
                index2 = i

        amount_out = pair_obj.amount_out(index1, index2, amount_in)
        if amount_out == 0:
            return None
        return amount_out
    except Exception as e:
        logging.error(
            f"Exception {e} occurred at calculate_amount_out_for_pair.")
```