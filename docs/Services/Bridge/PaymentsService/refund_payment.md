# Refund payment service
## About
When the destination transaction is failed , update payment status to refund and
if the user send refunding request for pay back 
this service start paying back the user source transaction and pay back amount into 
source wallet address

## Refund open payment
After user requested for pay back payment status updated to **refund_create_payment**
and the service trying to pay back to user

----------
### code logic

#### check method
Get all refund_create payments and if stay in this status more than 6 hours 
update payment status to operation for checking payment status

and if is new payment trying build refund transaction and sending into network

```python
def check(self):
    """
    start checking refunds payments service PAYMENT_TYPE_REFUND_CREATE
    and start refund payment flow
    :return:
    """
    calculating_fee_initialize()
    refund_create_payment_list = self.payment_db.objects.filter(
        status=PAYMENT_TYPE_REFUND_CREATE
    )
    for refund_create_payment in refund_create_payment_list:
        if refund_create_payment.modified_time <= (
                datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=6)):
            self.operation_payment(refund_create_payment)
        else:
            contract = self.set_contract(
                payment_transaction=refund_create_payment.transaction_src
            )
            transaction_result = contract.get_transaction(
                refund_create_payment.transaction_src.transaction_hash
            )

            if transaction_result is not None:
                status = transaction_result.get("status")
                if status == 1:  # success transaction status
                    refund_payment = self.create_transaction_refund(refund_create_payment)
                    if refund_payment is not None:
                        self.sending_payment(refund_payment)

                if status == 0:  # fail transaction status
                    self.operation_payment(refund_create_payment)
```


### Refund sending 

#### Code logic
If refund payment more than 6 hours update refund status tp operation status
else try getting transaction status from the network and update payment status
if transaction status is done payment

```python
def check(self):
    calculating_fee_initialize()
    refund_sending_payment_list = self.payment_db.objects.filter(
        status=PAYMENT_TYPE_REFUND_SENDING
    )
    BaseLogger.log_info(
        f"refund sending payment list: {len(refund_sending_payment_list)}",
    )
    for refund_sending_payment in refund_sending_payment_list:
        if refund_sending_payment.modified_time <= (
                datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=6)):
            self.operation_payment(refund_sending_payment)
        else:
            contract = self.set_contract(
                payment_transaction=refund_sending_payment.transaction_src
            )
            transaction_result = contract.get_transaction(refund_sending_payment.transaction_src.transaction_hash)
            if transaction_result is not None:
                status = transaction_result.get("status")
                if status == 1:  # success transaction status
                    self.done_payment(refund_sending_payment, transaction_result)

                if status == 0:  # fail transaction status
                    self.operation_payment(transaction_result)
```