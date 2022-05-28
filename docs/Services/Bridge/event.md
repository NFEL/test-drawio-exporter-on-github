# Event crawler service - intro
This microservice is working every 30 seconds for getting all events from our contracts in chains.
## Why need events?
we need events for validating our bridge input transactions with events data.

------
# Quick lunch
* Install requirements
```python
pip install -r requirements.txt
```

* create a database from mongo and named **event**.

> If you need more info about mongo db use [mongo documentation](https://www.mongodb.com/docs/).

* initialize base datas
```python
python db_initializer.py 
```

* run service
```python
python crawler_startup.py -m EventCrawler -n NETWORK
```

--------
# Functions logic

## Starting function
this function decision maker desids about how the service should be run
with how many process 

```python
def run_concurrent_process(method, workers=3, *args):

    if DEBUG:
        method()
    else:
        with ProcessPoolExecutor(max_workers=workers) as executor:
            futures = []
            i = 0
            while i < 1500:
                futures.append(executor.submit(method, *args, ))
                i += 1
            for future in concurrent.futures.as_completed(futures):
                try:
                    message = future.result()
                    if message is not None:
                        pass
                except Exception as e:
                    print(e)
```

## Base configs
.env
```
MONGO_CONNECTION_URL="mongodb://localhost"
BASE_PATH=api/bridgev3/
DEBUG=True
```
Add this configs in you **.env** file
MONGO_CONNECTION_URL is your mongo connection string "mongodb://username:password"
for more info about mongo connection use [mongo connection documentation](https://www.mongodb.com/docs/manual/reference/connection-string/)

------------------
## Code Logic

### EventCrawlerManager class

#### get_ready_chain method
```python
def get_ready_chain(self):
    while True:
        self.chain_info = self.chain_mongo_db.get_ready_chain()
        if self.chain_info is None:
            BaseLogger.log_warn("can not find free chain for crawl, sleep 10")
            sleep(10)
        if self.chain_info is not None:
            self.last_block = None
            BaseLogger.log_info(f"get chain {self.chain_info['chain_name']}")
            break
```
Get chains for get events from network
the condition of free chains is **busy** = False and **next_crawl_date_time** < now

> chains crawl every **40** second

#### start_store_events method

```python
def start_store_events(self, block_number, steps=2000):
    to_block = block_number
    while True:
        from_block = to_block - steps
        if to_block < self.chain_info["last_block"]:
            from_block = block_number

        event_data = self.get_event(from_block=from_block, to_block=to_block)
        if len(event_data) > 0:
            self.export_and_save(event_data)

        to_block -= steps
        sleep(1)
        if self.is_not_valid_to_continue(block_number, from_block):
            self.chain_mongo_db.update_last_block(self.chain_info.get("_id"), block_number)
            self.chain_mongo_db.update_busy_false(self.chain_info.get("_id"))
            return
```

Get the last block number and last crawled number and try to get blocks with 2000 steps by default
and if can find the new events from contract trying store event to **event** mongo collection

#### get_event method
```python
def get_event(self, from_block, to_block):
    while True:
        try:
            event_data = self.event_method.getLogs(
                fromBlock=from_block,
                toBlock=to_block
            )
            return event_data
        except Exception as e:
            BaseLogger.log_error(
                f"{self.chain_info.get('chain_name')}can not get event error message = {e}"
            )
```
Trying ro get events form network contract

#### is_not_valid_to_continue method
```python
def is_not_valid_to_continue(self, last_block, block_number):
    if self.last_block is None:
        print(last_block)
        self.last_block = last_block

    if block_number <= self.chain_info["last_block"]:
        return True
    if block_number == 0:
        return True
    return False
```
if getting block number == last block number 
event crawler is sleep for 40 seconds for new blocks
and function return True
else function return False and event service while getting new blocks with 2000 steps

#### clean_data method
Before storing new event into mongo event collection 
cleaning data and create a data structure and after that store data into mongo db
```python
def clean_data(self, input_data, network="ftm"):
    salt = first_search_key(input_data, "salt")
    transaction_hash = first_search_key(input_data, "transactionHash")
    amount = first_search_key(input_data, "amount")
    if salt is not None and isinstance(salt, bytes):
        salt = salt.hex()

    if transaction_hash is not None:
        input_data.pop("transactionHash")
        transaction_hash = transaction_hash.hex()

    input_data['args'].pop('amount')
    if amount is not None:
        amount = Decimal128(Decimal(amount))

    context = {
        "network": self.chain_info.get("chain_name"),
        "test_chain": self.chain_info.get("test_chain"),
        "date_time": first_search_key(input_data, "date_time"),
        "salt": salt,
        "transaction_hash": transaction_hash,
        "amount": amount,
        **input_data
    }

    return context
```