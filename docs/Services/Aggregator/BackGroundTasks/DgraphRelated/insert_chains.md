# Chain
Inserting chains into database is done by two methods of Chain class.

**save_chain**

converts the Chain object to a dictionary that can be inserted in database.
```python
    def save_chain(self):
        obj = {
            "uid": self.uid,
            "chain_id": self.chain_id.value,
            "dgraph.type": dt.CHAIN
        }

        return obj
```

**check_if_chain_is_token_or_dex_or_pair** 

Queries dgraph and checks if chain's uid already exist in database and if it exist schema type it has.
 ```python
    async def check_if_chain_is_token_or_dex_or_pair(self):
        obj = await dgraph_client().find_by_uid(self.uid, ["dgraph.type"])
        if obj is not None:
            for d_type in obj.get("dgraph.type"):
                if d_type != "Chain":
                    logging.info(
                        f"chain uid was used before {self.uid}: {obj.get('dgraph.type')}")
                    return True
 ```

