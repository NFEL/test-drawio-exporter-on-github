# Dgraph Client

### Schema

We store chains, dexes, pairs, tokens and error messages in dgraph.

#### Predicates:

```graphql
chain_id: int @index(int) .
address: string @index(hash) .
name: string @index(exact) .
balance: string .
allowance: string .
is_verified: bool @index(bool).
default: string .
symbol: string .
price: string .
burn_rate: int .
popularity: int .
factory: string .
enabled: bool .
pair_count: int .
protocol: string @index(exact) .
factory_uid: string .
token_addresses: string .
decimals: string .
decimal: int .
token_symbols: string .
reserves: string @index(exact) .
reserves_init: string @index(exact) .
lp_fee: string .
tr_fee: string .
hash: string .
A: string .
N_COINS: string .
rates: string .
swap_fee: string .
swap_enabled: bool .
weights: string .
mid_price: string .
oracle_price: string .
K: string .
R: int .
lpFeeRate: string .
mtFeeRate: string .
slip_fee: string .
msg : string .
status_code : int .
time: string .
ftomToken : string .
toToken : string .
chainId: int .
walletAddress: string .
slippage: int .
amount_out: string .
amount_in: string .
with_draw: bool .
timestamp: dateTime .
```

#### Facets:

```graphql
chain: uid @reverse .
tokens: [uid] @reverse .
pairs: [uid] @reverse .
p0: [uid] @reverse .
p1: [uid] @reverse .
p2: [uid] @reverse .
p3: [uid] @reverse .
p4: [uid] @reverse .
p5: [uid] @reverse .
p6: [uid] @reverse .
p7: [uid] @reverse .
p8: [uid] @reverse .
p9: [uid] @reverse .
p10: [uid] @reverse .
p11: [uid] @reverse .
p12: [uid] @reverse .
p13: [uid] @reverse .
p14: [uid] @reverse .
p15: [uid] @reverse .
p16: [uid] @reverse .
p17: [uid] @reverse .
p18: [uid] @reverse .
p19: [uid] @reverse .
```

### Types:

```
type Chain {
  chain_id
}

type Token {
  chain
  address
  name
  balance
  allowance
  is_verified
  decimal
  default
  symbol
  pairs
  price
  prices
  burn_rate
  popularity
  p0
  p1
  p2
  p3
  p4
  p5
  p6
  p7
  p8
  p9
  p10
  p11
  p12
  p13
  p14
  p15
  p16
  p17
  p18
  p19
}

type Dex {
  chain
  factory
  enabled
  name
  pair_count
  protocol
}

type Pair {
  chain
  address
  balance
  allowance
  is_verified
  default
  enabled
  symbol
  protocol
  factory
  factory_uid
  tokens
  token_addresses
  decimals
  token_symbols
  reserves
  reserves_init
  lp_fee
  tr_fee
  hash
  A
  N_COINS
  rates
  swap_fee
  swap_enabled
  weights
  mid_price
  oracle_price
  K
  R
  lpFeeRate
  mtFeeRate
  slip_fee
  p0
  p1
  p2
  p3
  p4
  p5
  p6
  p7
  p8
  p9
  p10
  p11
  p12
  p13
  p14
  p15
  p16
  p17
  p18
  p19
}

type Error {
    time
    msg
    status_code
    ftomToken
    toToken
    chainId
    walletAddress
    slippage
    amount_out
    amount_in
    with_draw

}
```

## Client

```python
class GraphqlClient:
    """A class inspired by MongoClient, connects to Dgraph Database via given
    Url, port and authentication credentials
    """

    def __init__(self, host: str, alpha_port: str, ratel_port: str, username: str = None, password: str = None, namespace: str = None) -> None:
        self.alpha_port = alpha_port
        self.ratel_port = ratel_port
        self.host = host
        self.username = username
        self.password = password
        self.namespace = namespace
        client_stub = pydgraph.DgraphClientStub(f'{host}:{ratel_port}')
        self.client = pydgraph.DgraphClient(client_stub)
        if username and password and namespace:
            self.client.login_into_namespace(username, password, namespace)
```
### Mutate
To insert or delete data we must use pydgraph's mutate function.
```python
async def mutate_dgraph(
        self,
        data: Union[Dict, List, str],
        delete: bool = False
    ):
        res = None
        try:
            txn = self.client.txn()
            if delete:
                txn.mutate(del_nquads=data)
            else:
                res = txn.mutate(set_obj=data)
            txn.commit()

        except _InactiveRpcError as e:
            logging.error(
                f' {datetime.now():%H:%M:%S} - {e}')

        finally:
            txn.discard()
        if res:
            return res
```
### Query
To query data we must use pydgraph's query function.
```python
async def query_dgraph(
        self,
        query_text: str
    ):
        try:    
            txn = self.client.txn(read_only=True)
            res = txn.query(query_text)
            data = json.loads(res.json).get("query")
            return data

        except Exception as e:
            logging.exception(
                f' {datetime.now():%H:%M:%S} - {e} at query_dgraph')
```
