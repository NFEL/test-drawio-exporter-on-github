# Create Facets

For given pairs and given amount in, calculates amount out for token0 -> token1, token1 -> token0 and so on.


## Generate Amount In and Edge

Takes an input value, From 2 to the power of 0, to, 2 to the power of that value generates amount in which are assumed in FTM price amount (This will be explained in Price section). The input default value is 20.

- 2 \*\* 0: p1
- 2 \*\* 1: p2
- 2 \*\* 1: p3
- 2 \*\* 1: p4
- 2 \*\* 1: p5
- 2 \*\* 1: p6
- 2 \*\* 1: p7
- 2 \*\* 1: p8
- 2 \*\* 1: p9
- 2 \*\* 1: p10
- 2 \*\* 1: p11
- 2 \*\* 1: p12
- 2 \*\* 1: p13
- 2 \*\* 1: p14
- 2 \*\* 1: p15
- 2 \*\* 1: p16
- 2 \*\* 1: p17
- 2 \*\* 1: p18
- 2 \*\* 1: p19

```python
def _amount_in_generator(power) -> Iterable[int]:
    amounts_in = []
    l = list(range(0, 2**power+1))
    p = int(math.log(len(l), 2))
    for i in range(0, p+1):
        amounts_in.append(l[2**i])

    return amounts_in

```

```python
def _edge_name(edge_index: int) -> str:
    return f"p{edge_index}"
```

## Generate Amount Out

### Calculate Amount Out

1. Finds pair's token addresses using pair.token_addresses and token indexes.
2. Gets token objects from redis using their addresses.
3. Converts amount in to none FTM amount.
4. Calculates amount out of given tokens and obtained amount in.
5. Converts the calculated amount out to FTM amount.

```python
def _calculate_amount_out(
    chain_id: int,
    pair: Pair,
    amount_in: NoDecimal,
    index1: int,
    index2: int,
):

    address1, address2 = pair.token_addresses[
        index1], pair.token_addresses[index2]
    token1 = Token.get_cache(
        address1, chain_id)
    token2 = Token.get_cache(
        address2, chain_id)

    a_in: NoDecimal = convert_from_ftm(amount_in, token1)

    if a_in is None:
        return None

    a_in: WithDecimal = a_in * 10 ** token1.decimal

    a_out: WithDecimal = pair.amount_out(index1, index2, a_in)

    amount_out: NoDecimal = convert_to_ftm(
        a_out / 10 ** token2.decimal, token2)

    return amount_out
```

### Connect Amount to Edges

1. Takes:

- pair's uid
- token0's uid
- token1's uid
- amount out of token0 -> token1
- amount out of token1 -> token0
- edge (p0...pn)

2. 
```python
   Sets facets =
   {

        "uid": pair_uid,
        relation: {
            "uid": token1,
            "pn|{token0}" : amount_out0,
            "pn|{token1}" : amount_out1
        }
   },
   {
        "uid": token0,
        relation: {
            "uid": pair_uid,
            "pn|{token1}" : amount_out0,
            "pn|{token0}" : amount_out1
        }
   }
```

```python
async def _connect_amount_out_to_edge(
    pair_uid: Uid,
    token_0_uid: Uid,
    token_1_uid: Uid,
    facets_0: Dict,
    facets_1: Dict,
    edge: str
):

    await dgraph_client().connect_nodes(
        uid0=pair_uid,
        uid1=token_1_uid,
        relation=edge,
        facets=facets_0
    )
    logging.info(f"pair {pair_uid} conncted to token {token_1_uid}")

    await dgraph_client().connect_nodes(
        uid0=token_0_uid,
        uid1=pair_uid,
        relation=edge,
        facets=facets_1
    )
    logging.info(f"token {token_0_uid} conncted to pair {pair_uid}"
```
