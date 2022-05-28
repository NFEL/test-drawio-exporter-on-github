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

