# Portioning

A class that help us to portion the input amount, find the best pair for each portion and calculate amount out for them.

## How it works

While exchanging tokens, in order to avoid price impact and gaining more output, we divide the input amount to different portions.

Assume that we have a pair with tokenA and tokenB like the image below:

![PAIR](../Diagrams/pair1.drawio)

And there are 4 types of requests:

- 0 - 50 $
- 50 - 1500 $
- 1500 - 10k $
- 10k <

Assume that some user requests 17 $ tokenA -> tokenB;

We divide the input amount into 16 and 1 .

And we calculate amount out of tokenA -> tokenB for following amounts:

- 16 $: 2\*\*4
- 8 $: 2\*\*3
- 4 $: 2\*\*2
- 2 $: 2\*\*1
- 1 $: 2\*\*0

Then we set amount in: amount out facets on pair.

The pair's chart would be something like:

![PAIR](../Diagrams/pair2.drawio)

### Binary portioning

As you observed, portioning works based on binary numbers.

The first portion is the closest base 2 (equal or less) number to the input amount, the second portion is the closest base 2 number of the remaining amount and so on.

The follow the below pattern:

- 2\*\*0 = 1
- 2\*\*1 = 2
- 2\*\*2 = 4
- 2\*\*3 = 8
- 2\*\*4 = 16
- 2\*\*5 = 32
- 2\*\*6 = 64
- ...

### Example

Assume that some user wants to exchange 1600 $ of tokenA to tokenB;

The input amounts would be:

```python
160 = 2 ** n
128 < 160 > 256
160 = 128 + 32
32 = 2 ** n
32 = 2 ** 5
portioning = 128 + 32
```

## Attributes:

- chain_id: ChainId
- token_in: Token
- token_out: Token
- amount_in_with_decimal: WithDecimal

## Methods:

- find_best_pair
- common_tokens
- burn_rate_amount_in
- burn_rate_amount_out
- calculate_real_amount_out
- portion_same_pair
- portion_best_path

![PAIR](../Diagrams/portioning.drawio)

## **init**

1. Sets:
   - chain_id
   - token_in
   - token_out
   - amount_in_with_decimal
   - amount_in_without_decimal
   - client
2. Sets ftm_amount_in_with_decimal by converting amount_in to FTM (network's value token) price.
3. Sets binary_string by converting amount_in_with_decimal to a binary number.

```python
    def __init__(
        self,
        chain_id: ChainId,
        amount_in_with_decimal: WithDecimal,
        token_in: Token,
        token_out: Token
        ) -> None:
        self.chain_id = chain_id
        self.has_been_populated = False
        self.token_in = token_in
        self.token_out = token_out
        self.amount_in_with_decimal = amount_in_with_decimal
        self.amount_in_without_decimal: NoDecimal = amount_in_with_decimal / \
            10 ** token_in.decimal
        self.pair = {}
        self.pair_amount_out = 0
        self.amount_out = 0

        async def populate_obj():
            if self.has_been_populated:
                return
            self.has_been_populated = True
            self.client = dgraph_client()
            self.ftm_amount_in_with_decimal = convert_to_ftm(
                self.amount_in_with_decimal, self.token_in)
            if not self.ftm_amount_in_with_decimal:
                logging.error(
                    f"Price of token_in: {self.token_in.uid} is {self.token_in.price} at Portioning.populate_obj.")
                self.binary_string = "0"
            else:
                self.binary_string = format(
                    round(self.ftm_amount_in_with_decimal / (10 ** self.token_in.decimal)), "b")
                self.binary_string = max(self.binary_string, '1')
        self.populate_obj = populate_obj

```

## 1. find_best_pair

Calls **find_pair_and_amount_out** function and returns pair and amount_out.

```python
    async def find_best_pair(self):
        amount_out, pair = await find_pair_and_amount_out(
            self.chain_id,
            self.token_in,
            self.token_out,
            self.amount_in_with_decimal
        )
        return amount_out, pair
```

## 2. burn_rate_amount_in

Some tokens are burn tokens, meaning some of it will be sent to an account that can only receive it.
This function checks if the input token is a burn token and if yes, calculates the amount of token that will burn and removes it from the input amount.

```python
    def burn_rate_amount_in(self, amount_in_with_decimal):
        in_burn_rate = self.token_in.burn_rate
        if in_burn_rate not in (None, 0):
            burning_amount_in = (
                amount_in_with_decimal * in_burn_rate) // cc.BURN_RATE_PERSISSION
            return burning_amount_in
        return amount_in_with_decimal
```

## 3. burn_rate_amount_out

This function checks if the output token is a burn token and if yes, calculates the amount of token that will burn and removes it from the output amount.

```python
    def burn_rate_amount_out(self, amount_out):
        out_burn_rate = self.token_out.burn_rate
        if out_burn_rate not in (None, 0):
            amount_out = (
                amount_out * out_burn_rate) // cc.BURN_RATE_PERSISSION
        return amount_out
```

## 4. calculate_real_amount_out

1. Checks if token_in is a burn token and if yes, calculates the new amount_in.
2. Calls **find_pair_and_amount_out** function that returns amount_out and pair.
3. Checks if token_out is a burn token and if yes, calculates the new amount_out.

```python
    async def calculate_real_amount_out(self, amount_in_with_decimal):
        try:
            amount_in_with_decimal = self.burn_rate_amount_in(
                amount_in_with_decimal
            )

            amount_out, pair = await find_pair_and_amount_out(
                self.chain_id,
                self.token_in,
                self.token_out,
                amount_in_with_decimal
            )
            if amount_out:
                amount_out = self.burn_rate_amount_out(
                    amount_out
                )
            return amount_out, pair
        except Exception as e:
            logging.error(
                f"Exception {e} occurred at Portioning.calculate_real_amount_out.")
            return None, None
```

## 5. portion_same_pair

While finding path, sometimes we pass through the same pair more than one time. if we use one pair for exchanging tokenA to tokenB more than once, we are practically paying extra fee without gaining any benefits.

This functions searches for repeated pairs and sums their input amount so we can pass through it just one time.

```python
    def portion_same_pairs(
        self,
        pairs: List,
        pair_amounts: Dict,
        pair: Pair,
    ):
        if pair_amounts.get(pair.address) is not None:

            portion = pairs[len(pair_amounts) - 1].get("portion") + \
                ((amount_0 /
                    self.amount_in_with_decimal) * 100)
            pairs[len(pair_amounts) - 1].update({"portion": portion})

            if pairs[len(pair_amounts) - 1].get("portion") > 100:
                pairs[len(pair_amounts) - 1].update({"portion": 100})

            amount_0 += pair_amounts.get(pair.address)
            pair_amounts.update({pair.address: amount_0})

        else:
            pair_amounts[pair.address] = amount_0
            pairs.append({"pairs": pair})
            pairs[len(pair_amounts) - 1].update({"portion": (
                amount_0 / self.amount_in_with_decimal) * 100})

            if pairs[len(pair_amounts) - 1].get("portion") > 100:
                pairs[len(pair_amounts) - 1].update({"portion": 100})
```

## 6. portion_best_path

Loops through binary_string (portions) and calculates **amount_in**, **pair** and **amount_out** for each portion and returns **amounts_in**, **total_amount_out** and **pairs**.

```python
async def portion_best_path(self) -> Tuple[List[WithDecimal], WithDecimal, List[Dict[str, Pair]]]:
        await self.populate_obj()
        pairs = []
        total_amount_out = 0
        pair_amounts = {}

        try:
            for index, item in enumerate(self.binary_string):
                if int(item) == 0:
                    continue

                power = len(self.binary_string) - index - 1
                amount_0_in_ftm_with_decimal = (
                    2 ** power) * (10 ** self.token_in.decimal)

                amount_0: WithDecimal = int(convert_from_ftm(
                    amount_0_in_ftm_with_decimal, self.token_in))

                if amount_0 > self.amount_in_with_decimal:
                    amount_0 = self.amount_in_with_decimal

                real_amount_out, pair_obj = await self.calculate_real_amount_out(amount_0)
                end = time.time_ns()
                logging.info(
                    f"Elapsed time at calculate_real_amount_out in line 108 of portioning is: {end-s}")
                if pair_obj is None:
                    return (None,) * 3

            self.portion_same_pairs(
                pairs, pair_amounts, pair_obj)
            total_amount_out += real_amount_out

            amounts_in = list(pair_amounts.values())
            return amounts_in, total_amount_out, pairs
        except Exception as e:
            logging.error(
                f"Exception {e} occurred at Portioning.portion_best_path.")
            return (None,) * 3
```
