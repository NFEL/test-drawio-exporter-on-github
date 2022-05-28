# Path

A class that help us to find paths with depth of one, two and three between fromToken and toToken.

## Attributes:

- chain_id: ChainId
- token_in: Token
- token_out: Token
- amount_in: WithDecimal

## Methods:

- is_common
- common_tokens
- find_common_tokens
- depth_one
- depth_two
- depth_three
- best_path

## **init**

```python
def __init__(
        self,
        chain_id: ChainId,
        token_in: Token,
        token_out: Token,
        amount_in: WithDecimal
    ) -> None:
        self.chain_id = chain_id
        self.token_in = token_in
        self.token_out = token_out
        self.amount_in = amount_in
        self.client: GraphqlClient = dgraph_client()
```

## 1. is_common

Takes to 2 tokens uid and checks if there are any common pairs between them.

```python
async def is_common(
    self,
    token_uid: Uid,
    base_token: Uid
) -> bool:
    from_token_to_base = await self.client.common_pairs(
        from_token=token_uid,
        to_token=base_token,
        pair_counts=1
    )
    if from_token_to_base:
        return True
    return False
```

Dgraph query for token_uid: "0x1" and base_token: "0x2":

```graphql
{query(func: uid(0x1)){
		    pairs _first @cascade {
                uid
			    tokens @filter(uid(0x2)){
                    uid
                    }
                }
            }
        }
```

## 2. common_tokens

Checks if token_in has any common pairs with base tokens and returns a list of them.

```python
async def common_tokens(
    self,
    token_uid: Uid,
    base_tokens: List[Uid]
) -> List[Token]:

    common = set()
    for uid in base_tokens:
        if uid == token_uid:
            continue
        if await self.is_common(token_uid, base_token=uid):
            common.add(uid)

    return list(common)
```

## 3. find_common_tokens

1. Finds base tokens
   Tries to get base_tokens from redis and if couldn't find them, queries dgraph and gets fist 15 tokens which have the most pairs.

2. Finds depth one common tokens
   Returns a list of base token which have common pairs with token_in.

3. Finds depth two common tokens

For each token in depth one tokens list, checks if that token and base tokens have any common pairs and returns a list of lists, containing depth_one_tokens[i] and base tokens which have common pairs with that.

- Example:

```python
token_in_uid = "0x5"
base_tokens = [
    "0x1"
    "0x2",
    "0x3",
    "0x4",
    "0x6"
    ]
first_tokens = [
    "0x1",
    "0x3",
    "0x6"
    ]
second_tokens = [
    [
        "0x1",
        "0x2"
    ],
    [
        "0x3",
        "0x4",
        "0x5"
    ],
    [
        "0x6",
        "0x2"
    ]
]
```

```python
async def find_common_tokens(
    self
):
    BASE_TOKENS = get_base_tokens(self.chain_id)
    if not BASE_TOKENS:
        BASE_TOKENS = await find_base_tokens(self.chain_id)
    if not BASE_TOKENS:
        logging.error(
            "Couldn't find any base token at find_common_tokens.")
        return [], [[]]

    depth_one_tokens = await self.common_tokens(
        self.token_in.uid,
        BASE_TOKENS
    )

    if len(depth_one_tokens) < 1:
        logging.debug(
            "There are no common tokens between token_in and base tokens at find_common_tokens.")
        return [], [[]]

    depth_two_common_tokens = []
    for uid in depth_one_tokens:
        depth_two_common_tokens.append(await self.common_tokens(
            uid,
            BASE_TOKENS
        ))

    return depth_one_tokens, depth_two_common_tokens
```

## 4. depth_one

Checks if token_in has any common pairs with token_out, returns None, None, None if couldn't found any.

Calls **Portioning.portion_best_path** and returns amounts_in, amount_out and pairs.

```python
async def depth_one(
    self
):
    try:
        if await self.is_common(self.token_in.uid, self.token_out.uid):

            first_amounts_in, first_amount_out, first_pairs = await Portioning(
                self.chain_id,
                self.amount_in,
                self.token_in,
                self.token_out
            ).portion_best_path()
            return first_amounts_in, first_amount_out, first_pairs

        logging.debug(
            f"Couldn't find any common pairs between token_in:{self.token_in.uid} and token_out:{self.token_out.uid} at Path.depth_one.")
        return (None,) * 3
    except Exception as e:
        logging.error(f"Exception {e} occurred at Path.depth_on")
        return (None,) * 3
```

## 5. depth_two

Takes:

- depth_one_tokens

Returns:

- amounts_in
- amount_out
- pairs

1. For depth_one_token in depth_one_tokens; checks if depth_one_token has common pairs with token_out, if yes, makes the depth_one_token's object and calls **Portioning.portion_best_path()** for:

   - token_in
   - depth_one_token
   - amount_in

   Returns:

   - first_amounts_in
   - _amount_out
   - first_pairs

2. Calls **Portioning.calculate_real_amount_out()** for:

   - depth_one_token
   - token_out
   - _amount_out

   Returns:

   - last_amount_out
   - last_pair

3. Returns:

- (first_amounts_in, last_amounts_in)
- last_amount_out
- [{"pairs": last_pair, "portion": 100}]

```python
async def depth_two(
        self,
        common_tokens: List[Uid]
    ):
    try:
        for uid in common_tokens:
            if await self.is_common(uid, self.token_out.uid):
                base_token = await make_token_obj(
                    Token.get_identifier(
                        self.chain_id,
                        uid
                    ),
                    self.chain_id
                )

                first_portioning = Portioning(
                    self.chain_id,
                    self.amount_in,
                    self.token_in,
                    base_token
                )

                first_amounts_in, _amount_out, first_pairs = await first_portioning.portion_best_path()
                if not _amount_out:
                    continue

                last_portioning = Portioning(
                    self.chain_id,
                    _amount_out,
                    base_token,
                    self.token_out
                )

                last_amounts_in = [_amount_out]
                last_amount_out, last_pair = await last_portioning.calculate_real_amount_out(_amount_out)

                if last_amount_out in (None, maximum):
                    continue

                last_pair = [{"pairs": last_pair, "portion": 100}]

                maximum = last_amount_out
                pairs = [first_pairs, last_pair]
                return (first_amounts_in, last_amounts_in), maximum, pairs

        if maximum == 0:
            logging.debug(
                f"Couldn't find any path with depth two between token_in:{self.token_in.uid} and token_out:{self.token_out.uid} at Path.depth_two.")
            return (None,) * 3
    except Exception as e:
        logging.error(f"Exception {e} occurred at Path.depth_two")
        return (None,) * 3
```

## 6. depth_three

Takes:

- depth_one_tokens
- depth_two_tokens

Returns:

- amounts_in
- amount_out
- pairs
- first_middle_token
- second_middle_token

1. For each first_uid in depth_one_tokens, finds the common tokens between first_uid and depth_two_tokens[i].
2. For each second_uid in second_uids, checks if second_uid has common pairs with token_out and if couldn't find any continues.

```python
for i, first_uid in enumerate(first_common_tokens):
    second_uids = await self.common_tokens(
        first_uid,
        second_common_tokens[i],
    )
    if not second_uids:
        continue
```

3. Makes first_uid's Token object.
4. Makes second_uid's Token object.

```python
    base_token_1 = await make_token_obj(
    Token.get_identifier(
        self.chain_id,
        first_uid
    ),
    self.chain_id
)
    base_token_2 = await make_token_obj(
    Token.get_identifier(
        self.chain_id,
        second_uid
    ),
    self.chain_id
)
```
5. Calls **Portioning.portion_best_path()** for:

   - token_in
   - base_token_1
   - amount_in

   Returns:
   - first_amounts_in
   - first_amount_out
   - first_pairs

```python
    first_portioning = Portioning(
        self.chain_id,
        self.amount_in,
        self.token_in,
        base_token_1
    )

    first_amounts_in, first_amount_out, first_pairs = await first_portioning.portion_best_path()
    first_step = base_token_1
    if not first_amount_out:
        continue
```

6. Calls **Portioning.calculate_real_amount_out() for:
    - base_token_1
    - base_token_2
    - first_amount_out
    
    Returns:
    - middle_amount_out
    - middle_pair

```python
    middle_portioning = Portioning(
        self.chain_id,
        first_amount_out,
        base_token_1,
        base_token_2
    )

    middle_amount_out, middle_pair = await middle_portioning.calculate_real_amount_out(first_amount_out)
    if not middle_amount_out:
        continue
    middle_amounts_in = [first_amount_out]
    middle_pairs = [{"pairs": middle_pair, "portion": 100}]
    second_step = base_token_2
```


7. Calls **Portioning.calculate_real_amount_out()** for:

   - base_token_2
   - token_out
   - middle_amount_out

   Returns:
   - last_amount_out
   - last_pair
```python
    last_portioning = Portioning(
        self.chain_id,
        middle_amount_out,
        base_token_2,
        self.token_out
    )

    last_amount_out, last_pair = await last_portioning.calculate_real_amount_out(middle_amount_out)

    if last_amount_out in (None, maximum):
        continue

    last_amounts_in = [middle_amount_out]
    last_pairs = [{"pairs": last_pair, "portion": 100}]

    if maximum > last_amount_out:
        continue

    maximum = last_amount_out
    amount_ins = [first_amounts_in,
                    middle_amounts_in, last_amounts_in]
    pairs = [first_pairs, middle_pairs, last_pairs]
```
Returns:
- [first_amounts_in, middle_amounts_in, last_amounts_in]
- last_amount_out
- first_pairs, middle_pairs, last_pairs]
- first_middle_token
- second_middle_token
```python
return amount_ins, maximum, pairs, first_step, second_step
```
                    
## 7. Best path

Return a list containing:

- first amounts in, first amount out and first pairs for depth one.
- second amounts in, second amount out and second pairs for depth two.
- third amounts in, third amount out, third pairs, first middle token and second middle token for depth three.
- Raises Errors.NoPathFound() if couldn't find any path.

```python
async def best_path(
        self
    ):
    depth_one_common_tokens, depth_two_common_tokens = await self.find_common_tokens()

    first_amounts_in, first_amount_out, first_pairs = await self.depth_one()

    second_amounts_in, second_amount_out, second_pairs = await self.depth_two(depth_one_common_tokens)

    third_amounts_in, third_amount_out, third_pairs, first_step, second_step = await self.depth_three(depth_one_common_tokens, depth_two_common_tokens)
    if first_pairs is None and second_pairs is None and third_pairs is None:
        raise Errors.NoPathFound()
    return [
        (first_amounts_in, first_amount_out, first_pairs),
        (second_amounts_in, second_amount_out, second_pairs),
        (third_amounts_in, third_amount_out,
            third_pairs, first_step, second_step)
    ]
```
