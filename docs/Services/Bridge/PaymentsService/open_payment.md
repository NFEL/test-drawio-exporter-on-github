# Open payment service
## About
This service is get open payments from the database and start to verify input transaction from the contract and 
event service and after the verifying input transaction trying sending out the transaction

### what transaction in(src_transaction) and transaction out(des_transaction)?
When someone trying to bridge between two networks 
first of all, build a transaction with our frontend app and send a transaction to our contract on our contract in src network
and after that event service tyring to get the contract event and verify source transaction and after verifying src transaction
service try sending des transaction

----------------------
## Code logic
> CheckOpenPayment class inherit from BaseContract

### checking open payments
this function get all open payments from database and check created dates

```python
def check(self):
    open_payment_list = self.get_open_payment_list()

    if len(open_payment_list) > 0:
        for open_payment in open_payment_list:
            if open_payment.created_time <= (
                    datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=1)):
                self.failed_transaction(open_payment)
            else:
                self.start_pay(open_payment=open_payment)
```
**self.get_open_payment_list()**
get all payments with "open_payment" status

if open payment, open more than one day open payment update to fail 

> If open payment open for 1 day it means user do not want to send transaction and reject the src transaction

After that start checking payment
```python
def start_pay(self, open_payment):
    event_list = self.find_key_in_mongo(open_payment.salt[2:])
```
get the open payment and search in events from Mongo DB **event crawler service**

payment salt :
payment salt is a unique key generated when creating an open payment with payment nonce and  random unique id payment key 
we generate salt to avoid **duplicate** payments and **valid sending payments** 

> payment salt store in open payment on postgres db and contract events

