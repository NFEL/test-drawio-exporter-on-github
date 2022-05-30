# Filter Facets
After setting facets (amount out) on pairs and tokens, we need to check if there is a facet with 0 value.

1. Queries dgraph and finds all of facets.
```graphql
{query(func: type(Token)){
                    p0 @facets { uid }
p1 @facets { uid }
p2 @facets { uid }
p3 @facets { uid }
p4 @facets { uid }
p5 @facets { uid }
p6 @facets { uid }
p7 @facets { uid }
p8 @facets { uid }
p9 @facets { uid }
p10 @facets { uid }
p11 @facets { uid }
p12 @facets { uid }
p13 @facets { uid }
p14 @facets { uid }
p15 @facets { uid }
p16 @facets { uid }
p17 @facets { uid }
p18 @facets { uid }
p19 @facets { uid }
}
}
```
2. Checks if any facet has value of 0 and if found any, deletes it.

```python
async def delete_facets_with_zero_value():
    token_facets = await dgraph_client().find_all_facets("Token")
    if token_facets is not None and len(token_facets) > 0:
        uids = set()
        for token_facet in token_facets:
            for facet in token_facet.values():
                for p in facet:
                    for value in p.values():
                        if value == 0:
                            for key in p.keys():
                                if "p" in key.split("|")[0]:
                                    uids.add(key.split("|")[1])

        deleted_facets = await delete_facets(list(uids))
        logging.info(f"{len(deleted_facets)} facets with 0 value was deleted.")
```
```python

async def delete_facets(uids: List[Uid]):
    deleted_facets = []
    for uid in uids:
        try:
            await dgraph_client().delete(
                uid,
                [
                    "@facets"
                ]
            )
            deleted_facets.append(uid)
        except Exception as e:
            logging.exception(
                f"Couldn't delete facet on token: {uid}, {e}")
    return deleted_facets
```
