# Insert Tokens
In this module, we are trying to get the token details of stored pairs from blockchain, and create Token object based on those details.
Only thing left here is to save them on dgraph (DB of choice).
1. Query dgraph and finds all token addresses of existing pairs.
2. Uses **Token**'s detail method to create token object of specific addresses.
3. Uses token **check_if_token_is_pair_or_dex** method to check if token already exists in database and if yes, what schema type it has.
4. Uses token **save_token** method to convert token object into a dictionary that can be inserted to database.
5. Inserts token dictionary to dgraph.


## Find token addresses
**get_all_pairs_token**
```python
async def get_all_pairs_tokens(chain_id: ChainId) -> List[List[Address]]:
    pairs = await dgraph_client().find_by_type(
        "Pair",
        [

            "token_addresses",
            "chain { chain_id }"
        ]
    )

    tokens_addresses = []
    for pair in pairs:
        token_addresses = split_pairs(chain_id, pair)
        if token_addresses is not None:
            tokens_addresses.append(token_addresses)

    return tokens_addresses
```
```python
def split_pairs(chain_id: ChainId, pair: Dict):
    try:
        if pair.get("chain").get("chain_id") == chain_id:
            token_addresses = pair.get("token_addresses").split("#")
            return token_addresses
        return None
    except Exception as e:
        logging.error(e)
        return None
```
## Get and save tokens
```python
async def get_and_save_tokens(
    chain_id: ChainId,
    tokens_addresses=List[List[Address]]
) -> List[Token]:
    added_tokens = []
    for token_addresses in tokens_addresses:
        for token_address in token_addresses:
            try:
                token = Token.detail(
                    token_address,
                    chain_id,
                    Network(chain_id).web3_client,
                    redis_client(chain_id)
                )
                if token is None:
                    logging.error(
                        f"Couldn't make token {token_address} but it's address exist in a pair, at get_and_save_tokens.")
                    continue
                if await token.check_if_token_is_pair_or_dex():
                    logging.warning(
                        "Repeated dgraph.type at get_and_save_tokens.")
                    continue
                token_uid = token.uid
                token = token.save_token()
                if token_uid not in added_tokens:
                    await dgraph_client().insert(token)
                    logging.info(f"token: {token_uid} added")
                    print(f"token: {token_uid} added")
                    added_tokens.append(token_uid)
            except Exception as e:
                logging.exception(
                    f"Expection {e} occured at get_and_save_tokens.")

```

## Token class
**detail**

1. Checks if token is cached in redis as a bad token.
2. Check if token is cached in redis as a good token.
3. Checks if token is amm pair or amm factory and if yes, caches it as a bad token and returns None.
4. Gets token's details (name, symbol and decimal) by calling cls._token_network_detail.
5. Makes the token object and caches it in redis.

```python
    @classmethod
    def detail(
        cls,
        address,
        chain,
        w3,
        _redis_client
    ) -> Token:
        if cls._is_bad_token(address, _redis_client):
            return None
        token = Token.get_cache(
            address,
            chain
        )
        if token is not None:
            return token
        _c = w3.eth.contract(address, abi=ABI.TOKEN)
        time.sleep(
            Redis.rpc_request(
                chain=chain,
                count=3
            )
        )
        if (
            not cls._is_addres_amm_pair(address, w3) and
            not cls._is_address_amm_factory(address, w3)
        ):
            token_details = cls._token_network_detail(_c)
            if token_details:
                token = cls(**{
                    "chain_id": chain,
                    "address": address,
                    **token_details
                })
                token.cache()
                return token
        cls._cache_bad_token_address(address, _redis_client)
        return None
```

**token_network_detail**

Uses batch contract's "callContractsWithStruct" function to find name, symbol and decimals of token. Contract's logic will be explained in Contract section.
```python
    @classmethod
    def _token_network_detail(cls, address: Address, batch_contract: Contract, _c: Contract) -> RawToken:
        try:
            result = batch_contract.functions.callContractsWithStruct(cls.token_entries(_c=_c,address=address)).call()
            token_details = cls.decode_batch_output(_c, result)
            return token_details
        except Exception as e:
            logging.exception(e)
            return None
```
**token_entries**

Uses "contract.functions._encode_traction_data()" to find batch contract's callContractsWithStruct function entries.
```python
    @classmethod
    def token_entries(cls, _c: Contract, address: Address):
        try:
            # name = _c.functions.name()._encode_transaction_data()
            # symbol = _c.functions.symbol()._encode_transaction_data()
            # decimal = _c.functions.decimals()._encode_transaction_data()
            # return [[address, name], [address, symbol], [address, decimal]]
            return [[address, '0x06fdde03'], [address, '0x95d89b41'], [address, '0x313ce567']]
        except Exception as e:
            logging.exception(f"Exception {e} occured at Token.token_entries.")
```
**decode_batch_output**

Decodes callContractsWithStruct's output witch is a list of bytes.
```python
    @classmethod
    def decode_batch_output(cls, _c: Contract, batch_output:List):
        try:
            try:
                name_len = int(batch_output[0].hex()[64:128],16)
                name = bytes.fromhex(batch_output[0].hex()[128:192]).decode('ascii')[:name_len]
            except Exception as e:
                logging.exception(f"Exception {e} occured at Token.decode_batch_output.")
                name = _c.functions.name().call
            try:
                symbol_len = int(batch_output[1].hex()[64:128],16)
                symbol = bytes.fromhex(batch_output[1].hex()[128:192]).decode('ascii')[:symbol_len]
            except Exception as e:
                logging.exception(f"Exception {e} occured at Token.decode_batch_output.")
            decimal = int(batch_output[2].hex()[:64], 16)
            return {
                'name': name,
                'symbol':symbol,
                'decimal': decimal
            }
        except Exception as e:
            logging.exception(f"Exception {e} occured at Token.decode_batch_output.")
```

**check_if_token_is_pair_or_dex**

Queries dgraph and tries to find a node with token's uid, if found one, checks if it's schema type (dgraph.type) is equal to "Token" or not.
```python
    async def check_if_token_is_pair_or_dex(self):
        obj = await dgraph_client().find_by_uid(self.uid, ["dgraph.type"])
        if obj is not None:
            for d_type in obj.get("dgraph.type"):
                if d_type != "Token":
                    logging.info(
                        f"token uid was used before {self.uid}: {obj.get('dgraph.type')}")
                    return True
                return False
        return False
```

**save_token**

Converts the Token object to a dictionary. connects "Token" to "Chain" using "chain" edge.
```python
    def save_token(self):
        obj = self.dict()
        obj["uid"] = self.uid
        obj["dgraph.type"] = dt.TOKEN
        obj["burn_rate"] = self.burn_rate
        if self.price is not None:
            obj["price"] = str(self.price)
        obj["chain"] = {
            "uid": self.get_and_set_uid(
                self.chain_id.value,
                self.chain_id.value
            ),
            "chain_id": self.chain_id.value,
            "dgraph.type": dt.CHAIN
        }
        obj.pop("chain_id")
        return obj
```

## Insert tokens
**insert_tokens**
```python
async def insert_dexes(
        chain_id,
        dexes: List[RawDex] = None
):
    if dexes is None:
        dexes = read_data(chain_id)

    for dex in dexes:
        try:
            factory = DexProtocol(
                dex.get("protocol")
            ).factory_class(**dex)

            if await factory.check_if_dex_is_token_or_pair():
                continue
            factory = factory.save_dex()
            await dgraph_client().insert(factory)
            logging.info(f"factory {factory.get('uid')} added.")

        except Exception as e:
            logging.error(
                f' {datetime.now():%H:%M:%S} - {e} at fetch_dexes function. dex: {dex}')
            logging.info(f"protocol {dex.get('protocol')} does not exist")
```

## Insert tokens
```python
async def insert_tokens(
    chain_id: ChainId,
    addresses: List[Address] = None
) -> List[Token]:
    if addresses is None:
        addresses = await get_all_pairs_tokens(chain_id)
    return await get_and_save_tokens(chain_id, addresses)
```