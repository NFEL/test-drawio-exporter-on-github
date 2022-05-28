# Insert Dexes
1. Reads address book data and finds factories on specified chain.
2. Uses **DexProtocol**'s factory_class method to create Factory object for each protocol.
3. Uses dex **check_if_dex_is_token_or_pair** method to check if dex already exists in database and if yes, what schema type it has.
4. Uses dex **save_dex** method to convert dex object into a dictionary that can be inserted to database.
5. Inserts dex dictionary to dgraph.

## Read address book data
**address book**
```json
{
  "250": {
      "Solidly": {
      "name": "Solidly",
      "router": "0xa38cd27185a464914D3046f0AB9d43356B34829D",
      "factory": "0x3fAaB499b519fdC5819e3D7ed0C26111904cbc28",
      "type": 12
    }
  }
}
```
**read_data** parses the address book and returns a dictionary containing **chain_id**, **protocol**, **name**, **factory** and **router**.
```python
def read_data(chain_id: int,
              address_book_directory='Utils/address_book.json'    
              ) -> List[RawDex]:
    chain_id = str(chain_id)
    dexs = []
    parsed_data = parse_dex_file(address_book_directory)
    for dex in parsed_data.get(chain_id).values():
        dex_obj = {
            "chain_id": chain_id,
            "protocol": str(dex.get("type")),
            "name": dex.get("name"),
            "factory": dex.get("factory"),
            "router": dex.get("router")

        }
        dexs.append(dex_obj)
    return dexs
```
```python
@lru_cache(maxsize=10000)
def parse_dex_file(address_book_directory):

    with open(address_book_directory) as f:
        dexs = json.load(f)
        f.close()
        return dexs
```

## DexProtocol
an Enum class which specifies the Dex Factory class that must be used.
```python
class DexProtocol(Enum):
    UNISWAP = '1'
    MDEX = '2'
    MOONSWAP = '3'
    SPARTAN = '4'
    ELLIPSIS = '5'
    Vpeg = '6'
    AcryptoS = '7'
    DODOV2 = '8'
    DODOV1 = '9'
    SOULSWAP = '10'
    BEETHOVEN = '11'
    SOLIDLY = '12'
    Curve = '13'
    FrozenYougert = '14'

    @classmethod
    def _class_map(cls: DexProtocol) -> List[Dict]:
        '''
        selecting the factory class
        '''

        return {
            cls.UNISWAP: UniSwapFactory,
            cls.MDEX: MDEXFactory,
            cls.SOLIDLY: SolidlyFactory,
            cls.BEETHOVEN: BeethovenFactory,
            cls.SPARTAN: SpartanSwapFactory,
            cls.MOONSWAP: MoonSwapFactory,
            cls.ELLIPSIS: EllipsisFactory, 
            cls.AcryptoS: AcryptoSFactory,
            cls.DODOV2: DoDoV2Factory,
            cls.DODOV1: DoDoV1Factory,
            cls.SOULSWAP: SoulSwapFactory,
            cls.Vpeg: VpegFactory,
            cls.FrozenYougert: FrozenYogurtFactory,
            cls.Curve: CurveFactory
        }

    def _class_selector(self):
        '''
        get pair list
        '''
        return DexProtocol._class_map()[self]

    @property
    def factory_class(self):
        return self._class_selector()

```

## Dex class
**check_if_dex_is_token_or_pair** query dgraph and tries to find a node with dex'es uid, if found one, checks if it's schema type (dgraph.type) is equal to "Dex" or not.
```python
    async def check_if_dex_is_token_or_pair(self):
        obj = await dgraph_client().find_by_uid(self.uid, ["dgraph.type"])
        if obj is not None:
            for d_type in obj.get("dgraph.type"):
                if d_type == "Token" or d_type == "Pair":
                    logging.info(
                        f"dex uid was used before {self.uid}: {obj.get('dgraph.type')}")
                    return True
```

**save_dex** converts the Dex object (Factory object for each protocol) to a dictionary. connects "Dex" to "Chain" using "chain" edge.
```python
    def save_dex(self):
        chain_id = self.chain_id.value

        obj = self.dict()
        obj["uid"] = self.uid
        obj["dgraph.type"] = dt.DEX
        obj["chain"] = {
            "uid": self.get_uid(
                chain_id,
                chain_id),
            "chain_id": chain_id,
            "dgraph.type": dt.CHAIN
        }
        obj.pop("chain_id")

        return obj
```

## Insert dexes
**insert_dexes**
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

 