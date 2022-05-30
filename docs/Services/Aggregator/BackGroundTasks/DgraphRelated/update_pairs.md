# Update Pairs
Because of new transactions, reserves of pairs are constantly changing nad to calculate the right amount output we need to have updated reserves.
1. Deletes all of **changed_pairs** uids from redis. (For each pair, if it's reserves change, it will be cached again, using **decode_batch_output** method.)
2. Queries dgraph and gets all pairs.
3. Makes Pair object of pairs.
```python
async def get_all_kind_of_pairs(
    chain_id: ChainId
) -> List[Pair]:
    try:
        all_pairs = await dgraph_client().find_by_chain_id(
            chain_id,
            "Pair",
            [
                "uid",
                "expand(_all_)"
            ]
        )
        pairs = []
        all_pairs = all_pairs.get("~chain")
        for pair in all_pairs:
            pair_obj = await make_pair_obj(pair, chain_id)
            pairs.append(pair_obj)
        return pairs
    except Exception as e:
        logging.error(f"Exception {e} occured at get_all_kinda_pairs.")
```
4. For each pair, calls the **pair_entries** method in it's class and return the data that batch contract's "callContractsWithStruct" need.
```python
def get_all_kind_of_pairs_entries(pairs: List[Pair]) -> List[Tuple]:
    enteries = []
    for pair in pairs:
        try:

            enteries.append(pair.pair_entries())
        except Exception as e:
            print(e)
            logging.exception(
                f"protocol {pair.protocol} does not have pair_entries function")
    return enteries
```

5. Some pairs might have more than one entry, **sort_entries** sorts entries and return a list of tuples.
```python
def sort_entries(entries):
    new_entires = []
    for entry in entries:
        for item in entry:
            new_entires.append(tuple(item))
    return new_entires
```
6. Calls batch contract's callContractsWithStruct function which returns a list of bytes.
7. For each pair, decodes batch's output using pair's **decode_pair_output** method.
```python
async def update_pairs(chain_id: ChainId):
    delete_changed_pairs(chain_id)
    chain = Chain(chain_id=chain_id)
    pairs = await get_all_kind_of_pairs(chain_id)
    entries = get_all_kind_of_pairs_entries(pairs)
    new_entries = sort_entries(entries)

    c = chain.batch_everything_contract
    results = c.functions.callContractsWithStruct(new_entries).call()
    counter = 0
    for pair, _pair_entriez in zip(pairs, entries):
        try:
            _r_c = len(_pair_entriez)
            new_pair = pair.decode_batch_output(results[counter:counter+_r_c])
            await dgraph_client().insert(new_pair)
            logging.info(f"Updated pair {pair.uid}.")
            print(f"Updated pair {pair.uid}.")
            updated_pairs_num += 1
            counter += _r_c
        except Exception as e:
            logging.exception(
                f"Exception {e} occured in protocol {pair.protocol} decode_batch_output function."
            )
```
            