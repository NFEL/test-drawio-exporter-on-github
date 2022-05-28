# Filter Tokens
## Delete tokens with no price
After setting price predicate to tokens, some tokens might end up with no price (because of not having any common pairs with base tokens), therefore they have no use for us and we cannot calculate output amount for them, so we delete them. 
1. Queries dgraph and gets price of all tokens.
```python
tokens = await dgraph_client().find_by_chain_id(
        chain_id,
        "Token",
        [
            "uid",
            "price"
        ]
    )
    tokens = tokens.get("~chain")
```

2. Checks if tokens have price 
```python
for token in tokens:
        if token.get("price") in (None, 0):
            await dgraph_client().delete(token.get("uid"))
```

## Delete tokens with no pair
After deleting low reserve tokens, some tokens might end up with no pairs, therefore we cannot find route for them and they have no use for us.
1. Queries dgraph and gets pairs of all tokens.
```python
tokens = await dgraph_client().find_by_chain_id(
        chain_id,
        "Token",
        [
            "uid",
            "pairs { uid }"
        ]

    )
    tokens = tokens.get("~chain")
```
2. Checks if tokens have pair
```python
for token in tokens:
        if token is None:
            return None
        if token.get("pairs") is None:
            await dgraph_client().delete(token.get("uid"))
```
3. Check if token is really gone
```python
dgraph_type = await dgraph_client().find_by_uid(token.get("uid"), ["dgraph.type"])
            if dgraph_type:
                if dgraph_type.get("dgraph.type"):
                    logging.info("The delete function doesn't work correctly!")
```