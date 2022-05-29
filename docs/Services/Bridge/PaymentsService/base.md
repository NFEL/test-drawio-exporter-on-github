# Base diagram
---------------

# Data structure

## Base abstract model

Base abstract model inherit all models from this model

model field:

    created_time = models.DateTimeField(verbose_name=_('created time'), auto_now_add=True)
    modified_time = models.DateTimeField(verbose_name=_('modified time'), auto_now=True)
    deleted_time = models.DateTimeField(verbose_name=_('deleted time'), null=True, blank=True, editable=False)
    deleted = models.BooleanField(verbose_name=_('deleted'), default=False, editable=False)

deleted for safe delete data

--------------------

# Django apps

This project contain tree apps and four celery tasks

## Apps

### Chain app

It contains chains info, connections, tokens, tokens fee

#### Models

* Network model

fields:
```python
name = models.CharField(max_length=255, verbose_name="name")
symbol = models.CharField(max_length=255, verbose_name="symbol")
chain_id = models.IntegerField(verbose_name="chain_id")
bridge_contract_address = models.CharField(max_length=255, verbose_name="contract_address")
bridge_contract_abi = models.CharField(
max_length=256, default="./abi/contract_abi.json",
verbose_name="bridge_contract_abi"
)
decimal_digits = models.IntegerField(verbose_name="decimal_digits", default=18)
active = models.BooleanField(default=True, verbose_name="active")

```
for example:
  {
  name:fantom, symbl:ftm,
  chain_id:560, bridge_contract_address:our bridge contract address,
  bridge_contract_abi: abi address(defult=./abi/contract_abi.json),
  decimal_digits: native token decimal digits,
  active: True/False,
  }

* Connection model
```python

```
  This model store networks connections and can store many rpc connections from network
  '''' model fields : name, path, network, type
  '''' example: {name: any name , path: rpc connection, network: network relation, type: connection type}
* 

---------------

# Abstract base services

## BaseContract(ABC) class

### set_contract method

This method get a payment transaction and trying to connect network and set contract

```python
@staticmethod
def set_contract(payment_transaction):
    try:
        contract = ContractTasks(
            network_connections_list=payment_transaction.token.network.connections.all()
        )
        contract.set_contract(
            contract_address=payment_transaction.token.network.bridge_contract_address,
            contract_abi_path=payment_transaction.token.network.bridge_contract_abi
        )
        return contract
    except Exception as e:
        print(e)
```

### failed_transaction method

Update payment status to reverted

```python
@staticmethod
def failed_transaction(payment):
    try:
        with transaction.atomic():

            payment.transaction_des.status = TRANSACTION_TYPE_FAILED
            payment.transaction_des.save()

            payment.status = PAYMENT_TYPE_REVERTED
            payment.save()

            return payment
    except Exception as e:
        BaseLogger.log_error(e)
```

### failed_service_fee method

If calculated service fee and estimated gas is more than destnation transaction amount
payment update status to failed service fee (fail_service_fee)
and service can not build transaction

```python
@staticmethod
def failed_service_fee(payment):
    payment.status = PAYMENT_TYPE_FAIL_SERVICE_FEE
    payment.save()
```

### done_payment method

Update payment to done and stor contract transaction gas into payment info

```python
@staticmethod
def done_payment(payment, transaction_result, gas_price):
    try:
        with transaction.atomic():
            payment.transaction_des.status = TRANSACTION_TYPE_DONE
            token_gas = (
                                transaction_result.gasUsed * gas_price
                        ) / 10 ** payment.transaction_des.token.network.decimal_digits
            real_gas = token_to_usd_convert(token_gas, payment.transaction_des.token.network.symbol)
            payment.transaction_des.gas_price = gas_price
            payment.transaction_des.real_gas = real_gas
            payment.transaction_des.save()

            payment.status = PAYMENT_TYPE_DONE
            payment.save()
            BaseLogger.log_info(
                f"payment_key:{payment.payment_key} ,"
                f"update payment status to done",
            )
            return payment
    except Exception as e:
        BaseLogger.log_error(e)
```

### save_gas_info_to_model method

Get gas info form des transaction and store in payment info

```python
@staticmethod
def save_gas_info_to_model(
        transaction_data, gas_price,
        estimate_gas, token_usdc_price,
        calculated_gas_fee_dollar,
        final_amount
):
    with transaction.atomic():
        transaction_data.gas_price = gas_price
        transaction_data.estimate_gas = estimate_gas
        transaction_data.token_usdc_price = token_usdc_price
        transaction_data.calculated_gas_fee_dollar = calculated_gas_fee_dollar
        transaction_data.amount = final_amount
        transaction_data.save()
```

### is_valid_payment_and_transaction_info method

Validate open payment with transaction info and evnet crawler

```python
@staticmethod
def is_valid_payment_and_transaction_info(payment, event):
    from mongo.utiles import first_search_key
    if payment.salt[2:] == event.get("salt"):
        event_amount = first_search_key(event, "amount")
        if event_amount is not None:
            event_amount = event_amount.to_decimal()
            if payment.amount == event_amount:
                if Web3.toChecksumAddress(
                        payment.wallet.wallet_address
                ) == Web3.toChecksumAddress(
                    first_search_key(event, "sender")
                ):
                    if Web3.toChecksumAddress(
                            payment.transaction_src.token.token_contract_address
                    ) == Web3.toChecksumAddress(
                        first_search_key(event, "token")
                    ):
                        return True

                    if payment.transaction_src.token.is_native_token or payment.transaction_des.token.is_native_token:
                        return True
    return False
```

--------

# Token fee calculator
